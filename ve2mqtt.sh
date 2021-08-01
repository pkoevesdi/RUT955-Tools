#!/bin/sh
############
# VE 2 MQTT

temp_dir=$(mktemp -d)

mkfifo "$temp_dir/out" "$temp_dir/err"
<"$temp_dir/out" logger -p user.notice -t "$(basename "$0")" &
<"$temp_dir/err" logger -p user.error -t "$(basename "$0")" &
exec >"$temp_dir/out" 2>"$temp_dir/err"

fh="/dev/ttyUSB0"
stty -F $fh 19200 raw -echo -echoe -echok
fields=" PID FW SER V I VPV PPV CS MPPT OR ERR LOAD H19 H20 H21 H22 H23 HSDS "
backpipe="$temp_dir/mqttve_backpipe"
pidfile="$temp_dir/mqttve_pidfile"

ctrl_c() {
  kill $(cat "$pidfile")
  rm -rf $temp_dir
  [ "$?" -eq "0" ] && {
    echo "Exit success."
    exit 0
  } || exit 1
}


listen() {

  while true
  do
     curl -s mqtt://localhost:1883
     ret=$?
     [ $ret -eq 3 ] && unset tmp && unset ret && break
     [ -z $tmp ] && echo "waiting for mqtt broker" && tmp=1
     sleep 1
  done

  [ ! -p "$backpipe" ] && mkfifo $backpipe
  (cat $fh $* >$backpipe) &
  echo "$!" >"$pidfile"

  echo "started."

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
				ubus call ioman.relay.relay0 update '{"state":"closed"}'
			elif [ "$value" == "OFF" ]; then
				ubus call ioman.relay.relay0 update '{"state":"open"}'
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
  trap ctrl_c INT TERM QUIT
  listen $*
  ;;
esac
