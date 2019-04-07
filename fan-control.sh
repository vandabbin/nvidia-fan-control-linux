#!/bin/bash
# Fan Control Script
# Turn on Nvidia Fan Controller

# FanControl Configuration Path
fanConfig=/home/$(whoami)/.fancontrol

# Export Display (For Headless Use)
export DISPLAY=':0'

# Get Number of Connected GPUs
numGPUs=$(nvidia-smi --query-gpu=count --format=csv,noheader -i 0)

# Day Curve Start Time (24 Hour Time)
dCurveStart=12
# Night Curve Start Time (24 Hour Time)
nCurveStart=23

# Fan Curve Temperature Thresholds (In Celsius)
MAXTHRESHOLD=65		# Fans will run at 100% if hotter than this temperature
tempThresh[0]=60	# <-- Apply curve[0] if hotter than
tempThresh[1]=55	# <-- Apply curve[1] if hotter than
tempThresh[2]=50	# <-- Apply curve[2] if hotter than
tempThresh[3]=45	# <-- Apply curve[3] if hotter than
tempThresh[4]=40	# <-- Apply curve[4] if hotter than
			# """ Apply curve[5] if cooler than

# Day Curve	Night Curve
dCurve[0]=95 && nCurve[0]=80
dCurve[1]=90 && nCurve[1]=70
dCurve[2]=80 && nCurve[2]=60
dCurve[3]=70 && nCurve[3]=40
dCurve[4]=50 && nCurve[4]=30
dCurve[5]=40 && nCurve[5]=20

# Default Speed Setting
defaultSpeed=60

# Persistent Fan Curve Refresh Interval
refresh=30

runCurve()
{
	# Get GPU Temperature and Current FanSpeed
	IFS=$'\n'
	gputemp=($(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader))
	currentSpeed=($(nvidia-smi --query-gpu=fan.speed --format=csv,noheader | awk '{print $1}'))
	unset IFS

	time=$(date +'%H') # Get the time

	# Checks time to apply day or night curve 
	if [ $time -lt $dCurveStart -o $time -gt $nCurveStart ]
	then
		curve=("${nCurve[@]}")

	else
		curve=("${dCurve[@]}")
	fi

	# Loop through each GPU
	for i in $(seq 0 $(($numGPUs-1)))
	do
		# Set speed to 100 as a failsafe
		speed=100
	
		# Set speed to appropriate value from curve
		# Change these Temperature Thresholds if desired or Add more
		if [ ${gputemp[$i]} -ge $MAXTHRESHOLD ]
		then
			speed=100 
		elif [ ${gputemp[$i]} -ge ${tempThresh[0]} ]
		then
			speed=${curve[0]}
	
		elif [ ${gputemp[$i]} -ge ${tempThresh[1]} ]
		then
			speed=${curve[1]}
		elif [ ${gputemp[$i]} -ge ${tempThresh[2]} ]
		then
			speed=${curve[2]}
	
		elif [ ${gputemp[$i]} -ge ${tempThresh[3]} ]
		then
			speed=${curve[3]}
	
		elif [ ${gputemp[$i]} -gt ${tempThresh[4]} ]
		then
			speed=${curve[4]}
	
		elif [ ${gputemp[$i]} -le ${tempThresh[4]} ]
		then 
			speed=${curve[5]}
		fi
	
		# Apply fan speed if speed has changed
		if [ $speed -ne ${currentSpeed[$i]} ]
		then
			nvidia-settings \
				-a "[gpu:$i]/GPUFanControlState=1" \
				-a "[fan:$i]/GPUTargetFanSpeed=$speed" 
		fi
	done
}

case "$1" in
	startup)
		for i in $(seq 0 $(($numGPUs-1)))
		do
			nvidia-settings \
			-a "[gpu:$i]/GPUFanControlState=1" \
			-a "[fan:$i]/GPUTargetFanSpeed=$defaultSpeed" & 
		done
		;;

	# Set Fan Speed for all GPU Fans
	set|s)
		case "$2" in
			# Enable Fan Curve (Use with Cron)
			curve|c)
				speed="curve"
				;;
			# Enable Persistent Fan Curve (Use without Cron)
			pcurve|pc)
				speed="pcurve"
				;;
			# Set Speed to Default
			default|d)
				speed=$defaultSpeed
				;;
			# Set Speed to Max
			max|m)
				speed=100
				;;
			# Turn Fans Off
			off)
				speed=0
				;;
			# Set Fan Speed Manually
			*)
				# Test if Proper Input was given
				if [ $# -eq 2 ]
				then 
					# Is input a number that is less than or equal to 100?
					re='^[0-9]{,2}$'
					if [[ $2 =~ $re || $2 -eq 100 ]]
					then
						# Assign input as Speed
						speed=$2
					else
						speed=-99
					fi
				else
					speed=-99
				fi

				;;
		esac

		
		# Disable Manual Control and Enable Fan Curve
		if [ "$speed" == "curve" ]
		then
			# Change Configuration to Curve
			echo $speed > $fanConfig
			# Run Fan Curve
			$0 $speed
		elif [ "$speed" == "pcurve" ]
		then
			# Change Configuration to Persistant Curve
			echo $speed > $fanConfig
			printf "Persistant Curve Set\n"
			printf "Run '%s startup &' at Login\nOr\nRun '%s pcurve' in a terminal to monitor output\n" $0 $0
		elif [ $speed -ne -99 ]
		then
			# Enabling Manual Control and Disabling Fan Curve
			echo "manual" > $fanConfig
			# Loop through GPUs and Set Fan Speed
			for i in $(seq 0 $(($numGPUs-1)))
			do
				nvidia-settings \
				-a "[gpu:$i]/GPUFanControlState=1" \
				-a "[fan:$i]/GPUTargetFanSpeed=$speed"
			done
		else
			echo "Usage: $0 $1 {# Between 0 - 100|d (default)|m (max)|off}"
			
		fi
		;;

	# For testing Individual GPU Fan Settings
	dx)
		# Test if Proper Input was given
		if [ $# -eq 3 ]
		then
			# Is input $2 a valid GPU index?
			re='^[0-9]{,2}$'
			if [[ $2 =~ $re && $2 -lt $numGPUs ]]
			then
				# Is input $3 a number that is less than or equal to 100?
				if [[ $3 =~ $re || $3 -eq 100 ]]
				then
					# Set Fan Speed for Specified GPU
					nvidia-settings \
						-a "[gpu:$2]/GPUFanControlState=1" \
						-a "[fan:$2]/GPUTargetFanSpeed=${3}" 
				else
					err=-99
				fi
			else
				err=-99
			fi
		else
			err=-99
		fi

		if [ $err -eq -99 ]
		then
			echo "Usage: $0 $1 gpuIndex  FanSpeed Between 0 - 100"
		fi
		;;

	# Applys Fan Curve (For use with cron)
	curve|c)
		# Checks if Configuration File exists
		if [ ! -f $fanConfig ]
		then 
			# Doesn't exist so we will create it
			echo "curve" > $fanConfig
			# And then rerun
			$0 curve
		elif [ "$(cat $fanConfig)" == "curve" ]
		then 
			# Exists and is set to Curve!
			runCurve
		fi
		;;
	
	# Applys Persistant Fan Curve (For use without cron)
	pcurve|pc)
		# Checks if Configuratio File exists
		if [ ! -f $fanConfig ]
		then
			# Doesn't exist so we will creat it
			echo "pcurve" > $fanConfig
			# And then rerun
			$0 pcurve
		elif [ "$(cat $fanConfig)" == "pcurve" ]
		then
			# Exists and is set to Persistant Curve!
			while [ "$(cat $fanConfig)" == "pcurve" ]
			do
				runCurve
				sleep $refresh
			done
		fi
		;;

	# Display GPU Fan and Temp Status
	info|i)    
		IFS=$'\n'
		# Retrieve GPU Names,  Fan Speed, and Temperature
		query=($(nvidia-smi --query-gpu=name,fan.speed,temperature.gpu --format=csv,noheader))
		# Retrieve GPU Fan RPM
		query_rpm=($(nvidia-settings -q GPUCurrentFanSpeedRPM | grep -i "fan:" | awk '{print $4}' | awk -F '.' '{print $1}'))

		# Summary format
		# Nvidia Fan Info
		# | Card |		| Fan Speed |	| Fan RPM |	| GPU Temp |
		# Geforce GTX 1080 Ti	     50%	    1600	     53°

		# Loop through GPUs to compile summary
		for i in $(seq 0 $(($numGPUs-1)))
		do
			card=$(echo ${query[$i]} | awk -F ', ' '{print $1}')
			fan_speed=$(echo ${query[$i]} | awk -F ', ' '{print $2}' | awk '{print $1}')
			fan_rpm=$(echo ${query_rpm[$i]})
			temp=$(echo ${query[$i]} | awk -F ', ' '{print $3}')
			summary[$i]="$i: $card\t     $fan_speed%\t    $fan_rpm\t     $temp°"
		done
		
		# Print out Header
		echo "Nvidia Fan Info"
		echo "| Card |		| Fan Speed |	| Fan RPM |	| GPU Temp |"
		# Print out Summary
		for x in ${summary[@]}
		do
			echo -e $x
		done
		unset IFS
		;;
		
		
	*)
		echo "Usage: $0 {startup|set|dx(diagnose)|curve|pcurve|info)}"
		exit 2
esac

exit 0
