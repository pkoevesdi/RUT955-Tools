# MQTT-Logger
Simple MQTT-Logger for Busybox or other shells. Writes all MQTT messages from subscribed topics into a file.
Call script with same options like for [mosquitto_sub](https://mosquitto.org/man/mosquitto_sub-1.html). '-v' gets added. Configure output directory and other parameters inside script.

Tested on a router Teltonika RUT955 running BusyBox v1.30.1 () built-in shell (ash)

Based on https://unix.stackexchange.com/a/274224
