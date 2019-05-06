#!/bin/bash
# Fan Control Script w/ Fan Curve

#####################################
###     Configurable Settings     ###
#####################################

# FanControl Configuration Path
fanConfig=$HOME/.fancontrol

# Day Curve Start Time (24 Hour Time)
dCurveStart=12
# Night Curve Start Time (24 Hour Time)
nCurveStart=23
# Night Curve Enable/Disable (true/false)
# Disable if you don't want seperate day and night curves
nCurveEnabled=true

# Fan Curve Temperature Thresholds (In Celsius)
MAXTHRESHOLD=65		# Fans will run at 100% if hotter than this temperature
tempThresh[0]=60	# <-- Apply curve[0] if hotter than
tempThresh[1]=55	# <-- Apply curve[1] if hotter than
tempThresh[2]=50	# <-- Apply curve[2] if hotter than
tempThresh[3]=45	# <-- Apply curve[3] if hotter than
tempThresh[4]=40	# <-- Apply curve[4] if hotter than
			# """ Apply curve[5] if cooler than

# When Adding Curve Points you must also add temperature thresholds.
# There must always be one less temperature threshold (Excluding MAXTHRESHOLD)
# then there is curve point for the script to work.

# Day Curve    Night Curve
dCurve[0]=95; nCurve[0]=80
dCurve[1]=90; nCurve[1]=70
dCurve[2]=80; nCurve[2]=60
dCurve[3]=70; nCurve[3]=40
dCurve[4]=50; nCurve[4]=30
dCurve[5]=40; nCurve[5]=20

# Default Fan Speed Setting
defaultSpeed=60

# Persistent Fan Curve Refresh Interval
refresh=30

#####################################
###   End Configurable Settings   ###
#####################################

# Export Display (For Headless Use)
export DISPLAY=':0'

# Get Number of Connected GPUs
numGPUs=$(nvidia-smi --query-gpu=count --format=csv,noheader -i 0)

# Function to enable manual fan control state on first run
initFCS()
{
	FanControlStates=($(nvidia-settings -q GPUFanControlState | grep 'Attribute' | awk -vFS=': ' -vRS='.' '{print $2}'))
	for i in ${FanControlStates[@]}; do
		if [ $i -eq 0 ]; then
			nvidia-settings -a "GPUFanControlState=1" > /dev/null 2>&1
			echo "Fan Control State Enabled"
			break
		fi
	done
}

runCurve()
{
	# Get GPU Temperature and Current FanSpeed
	IFS=$'\n'
	gputemp=($(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader))
	currentSpeed=($(nvidia-smi --query-gpu=fan.speed --format=csv,noheader | awk '{print $1}'))
	unset IFS

	[ $nCurveEnabled ] && cTime=$(date +'%H') # Get the time

	# Checks time to apply day or night curve 
	[ $nCurveEnabled ] && [ $cTime -lt $dCurveStart -o $cTime -gt $nCurveStart ] && curve=("${nCurve[@]}") || curve=("${dCurve[@]}")

	# Loop through each GPU
	for i in $(seq 0 $((numGPUs-1))); do
		speed=100

		# Set speed to appropriate value from curve
		if [ ${gputemp[$i]} -lt $MAXTHRESHOLD ]; then
			cPoint=$((${#curve[@]}-1))
			for c in $(seq 0 $cPoint); do
				index=$c
				case "$c" in
					$cPoint)
						comparison=-lt
						index=$((c-1))
						;;
					*)
						comparison=-ge
						;;
				esac

				[ ${gputemp[$i]} $comparison ${tempThresh[$index]} ] && { speed=${curve[$c]}; break; }
			done
		fi
	
		# Apply fan speed if speed has changed
		[ $speed -lt $((currentSpeed[i]-1)) -o $speed -gt $((currentSpeed[i]+1)) ] && nvidia-settings -a "[fan:$i]/GPUTargetFanSpeed=$speed"
	done
}

case "$1" in
	# Set Fan Speed for all GPU Fans
	set|s)
		case "$2" in
			# Enable Fan Curve (Use with Cron)
			curve|c)		speed="curve" ;;

			# Set Speed to Default
			default|d)		speed=$defaultSpeed ;;

			# Set Speed to Max
			max|m|100)		speed=100 ;;

			# Turn Fans Off
			off)			speed=0 ;;

			# Set Fan Speed Manually
			[0-9]|[1-9][0-9])	speed=$2 ;;

			# Improper Input Given
			*)			echo "Usage: $0 $1 {# Between 0 - 100|d (default)|m (max)|off|curve}"; exit 2 ;;
		esac
		
		case "$speed" in
			curve)
				echo curve > $fanConfig # Change Configuration to Curve
				$0 curve # Run Fan Curve
				;;
			*)
				echo manual > $fanConfig # Enabling Manual Control and Disabling Fan Curve
				initFCS
				nvidia-settings -a "GPUTargetFanSpeed=$speed"
				;;
		esac
		;;

	# For testing Individual GPU Fan Settings
	dx)
		# Test if Proper Input was given
		# Is input $2 a valid GPU index? Is input $3 a number that is less than or equal to 100?
		re='^[0-9]{,2}$'
		[ $# -eq 3 ] && [[ $2 =~ $re && $2 -lt $numGPUs ]] && [[ $3 =~ $re || $3 -eq 100 ]] \
		&& nvidia-settings \
			-a "[gpu:$2]/GPUFanControlState=1" \
			-a "[fan:$2]/GPUTargetFanSpeed=$3"

		[ $? -ne 0 ] &&	{ echo "Usage: $0 $1 gpuIndex  FanSpeed Between 0 - 100"; exit 2; }
		;;

	# Applies Fan Curve (For use with cron)
	curve|c)
		# Checks if Configuration File exists and create it if it doesn't
		[ ! -f $fanConfig ] && echo "curve" > $fanConfig

		# Run fan curve if configuration is set to curve
		case "$(cat $fanConfig)" in
			curve)
				initFCS
				runCurve
				;;
		esac
		;;
	
	# Applies Persistant Fan Curve (For use without cron)
	pcurve|pc)
		echo "pcurve" > $fanConfig
		initFCS
		# Run while configuration is set to pcurve
		while [ "$(cat $fanConfig)" == "pcurve" ]; do
			runCurve
			sleep $refresh
		done
		;;

	# Display GPU Fan and Temp Status
	info|i)    
		IFS=$'\n'
		# Retrieve GPU Names,  Fan Speed, and Temperature
		query=($(nvidia-smi --query-gpu=name,fan.speed,temperature.gpu --format=csv,noheader))
		# Retrieve GPU Fan RPM
		query_rpm=($(nvidia-settings -q GPUCurrentFanSpeedRPM | grep "fan:" | awk -vFS=': ' -vRS='.' '{print $2}'))

		# Summary format
		# Nvidia Fan Info
		# | Card |		| Fan Speed |	| Fan RPM |	| GPU Temp |
		# Geforce GTX 1080 Ti	     50%	    1600	     53°

		# Print out Header
		printf "Nvidia Fan Info\n| Card |\t\t| Fan Speed |\t| Fan RPM |\t| GPU Temp |\n"

		# Loop through GPUs to compile summary
		for i in $(seq 0 $((numGPUs-1))); do
			card=$(awk -F ', ' '{print $1}' <<< ${query[$i]})
			fan_speed=$(awk -F ', ' '{print $2}' <<< ${query[$i]} | awk '{print $1}')
			fan_rpm=${query_rpm[$i]}
			temp=$(awk -F ', ' '{print $3}' <<< ${query[$i]})
			printf "%s: %s\t     %s%%\t    %s\t     %s°\n" $i $card $fan_speed $fan_rpm $temp
		done
		
		unset IFS
		;;
		
	*)
		echo "Usage: $0 {set|dx(diagnose)|curve|pcurve|info)}"
		exit 2
esac

exit 0
