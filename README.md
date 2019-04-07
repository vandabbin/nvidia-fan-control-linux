# nvidia-fan-control-linux
Fan Curve Control Script for Nvidia GPUs on Linux

In order for this script to work, coolbits must be enabled in xorg.conf

This script allows directly setting fan speed on Nvidia GPUs either manually or with a "fan curve".
Supports Day and Night fan curves

Add a line to cron like this to enable automatic fan control:

```
* * * * *	~/fan-control.sh curve
```

If you don't wish to use cron but instead prefer a persistant running script in the background then you can!

then run the script in a terminal window with
```
$ fan-control.sh pcurve
```

Or set the script to run at login in the background
```
fan-control.sh pcurve &
```

Currently to adjust Fan Curve settings you must manually edit the script. 
I want to eventually load it from a config file but haven't bothered yet.

Example of Info Screen:

```
$ fan-control info
| Card |		| Fan Speed |	| Fan RPM |	| GPU Temp |
0: GeForce GTX 1080 Ti	     80%	    2632	     52°
1: GeForce GTX 1080 Ti	     80%	    2635	     53°
2: GeForce GTX 1080 Ti	     80%	    2661	     52°
3: GeForce GTX 1080	     70%	    2260	     48°
4: GeForce GTX 1080	     80%	    2908	     50°
5: GeForce GTX 1070 Ti	     90%	    3150	     55°
6: GeForce GTX 1070 Ti	     80%	    2802	     50°

```

Example of Setting Speed:
Note that setting a speed manually will disable fan curve if set in cron until 'set curve' command is given

```
$ fan-control.sh set 75        OR      $ fan-control.sh s 75

$ fan-control.sh set default   OR      $ fan-control.sh s d

$ fan-control.sh set max       OR      $ fan-control.sh s m

$ fan-control.sh set off       OR      $ fan-control.sh s off

$ fan-control.sh set curve     OR      $ fan-control.sh s c

$ fan-control.sh set pcurve    OR      $ fan-control.sh s pc
```

I hope this works for all of you as well as it does for me!
