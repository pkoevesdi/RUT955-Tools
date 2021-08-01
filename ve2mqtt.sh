#!/bin/sh
############
# GPS 2 MQTT

fh="/dev/ttyUSB0"
stty -F $fh 19200 raw -echo -echoe -echok
fields=" PID FW SER V I VPV PPV CS MPPT OR ERR LOAD H19 H20 H21 H22 H23 HSDS "
backpipe="/tmp/mqttve_backpipe"
pidfile="/tmp/mqttve_pidfile"

ctrl_c() {
  echo "Cleaning up..."
  kill $(cat $pidfile) 2>/dev/null
  rm -f $backpipe $pidfile
  [ "$?" -eq "0" ] && {
    echo "Exit success"
    exit 0
  } || exit 1
}

listen() {

  [ ! -p "$backpipe" ] && mkfifo $backpipe
  (cat $fh $* >$backpipe 2>/dev/null) &
  echo "$!" >$pidfile

  while read name value; do

    name=${name//[#+]/}
    value=${value//$'\r'/}
    case "$fields" in
    *" $name "*)
      #    echo "found: $name"
      eval old_val=\$$name
      if [ "$value" != "$old_val" ]; then
        # echo "changed: $name: $old_val -> $value"
        mosquitto_pub -h localhost -t "womo/mppt/$name" -m "$value"
        eval $name="'$value'"
		if [ "$name" == "LOAD" ]; then
			if [ "$value" == "ON" ]; then
				gpio.sh set DOUT2
			elif [ "$value" == "OFF" ]; then
				gpio.sh clear DOUT2
			fi
		fi
        #    else
        #      echo "value unchanged: $old_val -> $value"
      fi
      ;;
    *)
      #    echo "not found: $name"
      ;;
    esac

  done <$backpipe
}

usage() {
  echo "VE 2 Mqtt"
  echo "send Victron VE.direct messages via mqtt"
  echo "Configure parameters inside script."
}

case "$1" in
--h)
  usage
  exit 1
  ;;
*)
  trap ctrl_c INT
  listen $*
  ;;
esac
