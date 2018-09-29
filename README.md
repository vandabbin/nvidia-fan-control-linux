# fan-control-linux-gpu
Fan Control Script for Nvidia GPUs on Linux

This script allows directly setting fan speed on Nvidia GPUs either manually or with a "fan curve".
Supports Day and Night fan curves

Add a line to cron like this to enable automatic fan control:

```
*/1 * * * *	~/bin/fan-control curve
```

Currently to adjust Fan Curve you must manually edit the script. 
I want to eventually load it from a config file but haven't bothered yet.
