#!/bin/bash
# Fan Control Script
# Turn on Nvidia Fan Controller

# FanControl Configuration Path
fanConfig=~/.fancontrol

# Export Display (For use over ssh)
export DISPLAY=':0'

# Get Number of Connected GPUs
numGPUs=$(nvidia-smi --query-gpu=count --format=csv,noheader -i 0)

# Day Curve Start Time (24 Hour Time)
dCurveStart=12
# Night Curve Start Time (24 Hour Time)
nCurveStart=23
# Day Curve	Night Curve
dCurve[0]=95 && nCurve[0]=80
dCurve[1]=90 && nCurve[1]=70
dCurve[2]=80 && nCurve[2]=60
dCurve[3]=70 && nCurve[3]=40
dCurve[4]=50 && nCurve[4]=30
dCurve[5]=40 && nCurve[5]=20

case "$1" in
	startup)
		for i in $(seq 0 $(($numGPUs-1)))
		do
			nvidia-settings \
			-a "[gpu:$i]/GPUFanControlState=1" \
			-a "[fan:$i]/GPUTargetFanSpeed=100" & 
		done
		;;

	# Set Fan Speed for all GPU Fans
	set|s)
		case "$2" in
			curve|c)
				speed="curve"
				;;
			default|d)
				speed=40
				;;
			max|m)
				speed=100
				;;
			off)
				speed=0
				;;
			*)
				if [ $# -eq 2 ]
				then 
					if [ $2 -le 100 ]
					then
						if [ $2 -ge 0 ]
						then
							speed=$2
						fi
					else
						speed=-99
					fi
				else
					speed=-99
				fi

				;;
		esac

		
		if [ "$speed" == "curve" ]
		then
			echo $speed > $fanConfig
			$0 curve
		elif [ $speed -ne -99 ]
		then
			echo "manual" > $fanConfig
			for i in $(seq 0 $(($numGPUs-1)))
			do
				nvidia-settings \
				-a "[fan:$i]/GPUTargetFanSpeed=$speed"
			done
		else
			echo "Usage: $0 $1 {# Between 0 - 100|d (default)|m (max)|off}"
			
		fi
		;;

	dx)
		nvidia-settings \
			-a "[gpu:$2]/GPUFanControlState=1" \
			-a "[fan:$2]/GPUTargetFanSpeed=${3}"	
		;;

	# Applys Fan Curve (Add to cron for automatic use)
	curve|c)
		if [ ! -f $fanConfig ]
		then 
			echo "curve" > $fanConfig
			$0 curve
		elif [ "$(cat $fanConfig)" == "curve" ]
		then 
			# Loop through each GPU
			for i in $(seq 0 $(($numGPUs-1)))
			do
				# Get GPU Temperature and Current FanSpeed
				gputemp=$(nvidia-smi -i $i --query-gpu=temperature.gpu --format=csv,noheader)
				currentSpeed=$(nvidia-smi -i $i --query-gpu=fan.speed --format=csv,noheader | awk '{print $1}')
				# Set speed to 100 as a failsafe
				speed=100
				time=$(date +'%H') # Get the time
			
				# Checks time to apply day or night curve 
				if [ $time -lt $dCurveStart -o $time -gt $nCurveStart ]
				then
					curve=("${nCurve[@]}")
			
				else
					curve=("${dCurve[@]}")
				fi
			
				# Set speed to appropriate value from curve
				if [ $gputemp -ge 65 ]
				then 
					speed=100
			
				elif [ $gputemp -ge 60 ]
				then
					speed=${curve[0]}
			
				elif [ $gputemp -ge 55 ]
				then
					speed=${curve[1]}
				elif [ $gputemp -ge 50 ]
				then
					speed=${curve[2]}
			
				elif [ $gputemp -ge 45 ]
				then
					speed=${curve[3]}
			
				elif [ $gputemp -gt 40 ]
				then
					speed=${curve[4]}
			
				elif [ $gputemp -le 40 ]
				then 
					speed=${curve[5]}
				fi
			
				# Apply fan speed if speed has changed
				if [ $speed -ne $currentSpeed ]
				then
					nvidia-settings -a "[fan:${i}]/GPUTargetFanSpeed=${speed}"
				fi
			done
		fi
		;;

	# Display GPU Fan and Temp Status
	info|i)    
		IFS=$'\n'
		query=($(nvidia-smi --query-gpu=name,fan.speed,temperature.gpu --format=csv,noheader))
		query_rpm=($(nvidia-settings -q GPUCurrentFanSpeedRPM | grep -i "fan:" | awk '{print $4}' | awk -F '.' '{print $1}'))

		# Summary format
		# Nvidia Fan Info
		# | Card |		| Fan Speed |	| Fan RPM |	| GPU Temp |
		# Geforce GTX 1080 Ti	     50%	    1600	     53°

		for i in $(seq 0 $(($numGPUs-1)))
		do
			card=$(echo ${query[$i]} | awk -F ', ' '{print $1}')
			fan_speed=$(echo ${query[$i]} | awk -F ', ' '{print $2}' | awk '{print $1}')
			fan_rpm=$(echo ${query_rpm[$i]})
			temp=$(echo ${query[$i]} | awk -F ', ' '{print $3}')
			summary[$i]="$i: $card\t     $fan_speed%\t    $fan_rpm\t     $temp°"
		done
		
		echo "Nvidia Fan Info"
		echo "| Card |		| Fan Speed |	| Fan RPM |	| GPU Temp |"
		for x in ${summary[@]}
		do
			echo -e $x
		done
		;;
		
		
	*)
		echo "Usage: $0 {startup|set|dx(diagnose)|info)}"
		exit 2
esac

exit 0
