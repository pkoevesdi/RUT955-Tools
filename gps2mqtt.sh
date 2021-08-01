#!/bin/sh
############
# GPS 2 MQTT

temp_dir=$(mktemp -d)

mkfifo "$temp_dir/out" "$temp_dir/err"
<"$temp_dir/out" logger -p user.notice -t "$(basename "$0")" &
<"$temp_dir/err" logger -p user.error -t "$(basename "$0")" &
exec >"$temp_dir/out" 2>"$temp_dir/err"

thresdist=10 # sending threshold in m distance
oldlat=0
oldlong=0

Calc() awk 'BEGIN{printf "%0.10f", '$*'}'

ctrl_c() {
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

  echo "started."

  while true
  do
    status=$(gpsctl -s)
    if [ $status -ge 1 ]
    then

      lat=$(gpsctl -i)
      long=$(gpsctl -x)

      # nach https://www.movable-type.co.uk/scripts/latlong.html:
      #a=$(Calc "sin(($lat-$oldlat)/2)^2+sin(($long-$oldlong)/2)^2*cos($lat)*cos($oldlat)")
      #dist=$(Calc "6371000*2*atan2(sqrt($a),sqrt(1-$a))");
      # Vereinfachung Pythagoras, ok fuer kleine Abstaende:
      dist=$(Calc "6371000*sqrt(($lat-$oldlat)^2+($long-$oldlong)^2)/180*3.1415926")

      if [ $(awk "BEGIN{if ($dist>$thresdist) print 1;else print 0}") == 1 ]
      then
        mosquitto_pub -h localhost -t womo/RUT955/gps -m "$(gpsctl -e),$lat,$long,$(gpsctl -a),$(gpsctl -v),$(gpsctl -p),$(gpsctl -a),$status,$(gpsctl -u)"
        oldlat=$lat
        oldlong=$long
      fi
    fi
    sleep 1

  done
}

usage() {
  echo "GPS 2 Mqtt"
  echo "send gps parameters via mqtt"
  echo "Configure parameters inside script."
}

case "$1" in
--h)
  usage
  exit 1
  ;;
*)
  trap ctrl_c INT TERM QUIT
  listen
  ;;
esac
