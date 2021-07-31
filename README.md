# MQTT-Logger
Simple MQTT-Logger for Busybox or other shells. Writes all MQTT messages from subscribed topics comma separated into a file. 
Based on https://unix.stackexchange.com/a/274224

## Features
- Log rotation when disk space below threshold (configurable)
- Logfiles split by size (configurable)
- option to log into subfolders by topic or all topics together into same log file. If the latter, then a topic column is added.

Call script with same options like for [mosquitto_sub](https://mosquitto.org/man/mosquitto_sub-1.html). '-v' gets added. Configure output directory and other parameters inside script.

:warning: **If using the outputsubdirs flag** (for logging into subfolders by topic) with topics that differ much in their posting frequency, you can easily loose data because of the log rotation. The rarely used topic can easily become the oldest file (by modification time) and if the configured space quota is used up, it gets deleted. To workaround make sure, all topics get enough feed to not become overaged or make the split file size small enough that also the rarely used topics produce enought split files.

Tested on a router Teltonika RUT955 running BusyBox v1.30.1 () built-in shell (ash)

## Dependencies:
- mqtt broker (officially avaliable as a package from teltonika RUT955, just needs to be installed and activated via WebGUI, or use remote broker)
- mqtt client (installable on RUT955 with ``opkg install mosquitto-client``. If you get an error ``Unknown package``, try ``opkg update`` before. From new firmware RUT9_R_00.07.00 on You need ``opkg install mosquitto-client-ssl`` instead.)

