#!/bin/sh
############
# GPS 2 MQTT

temp_dir=$(mktemp -d)

mkfifo "$temp_dir/out" "$temp_dir/err"
<"$temp_dir/out" logger -p user.notice -t "$(basename "$0")" &
<"$temp_dir/err" logger -p user.error -t "$(basename "$0")" &
exec >"$temp_dir/out" 2>"$temp_dir/err"

thresdist=10 # sending threshold in m distance

backpipe="$temp_dir/mqttgps_backpipe"
pidfile="$temp_dir/mqttgps_pidfile"
oldlat=0
oldlong=0

Calc() awk 'BEGIN{printf "%0.10f", '$*'}'

ctrl_c() {
  kill $(cat "$pidfile")
  rm -rf $temp_dir
  [ "$?" -eq "0" ] && {
    echo "Exit success."
    exit 0
  } || exit 1
}

listen() {

  echo "started."

  while true; do
    #echo "$message"
    if [ $(echo "$message" | cut -d, -f 1) == "$dataset" ] &&
      [ $(echo "$message" | cut -d, -f 7) -ge 1 ] &&
      [ $(Checksum $(echo "$message" | cut -d$ -f2 | cut -d* -f1)) == $((0x$(echo "$message" | cut -d* -f2))) ]; then

      lat=$(echo "$message" | cut -d, -f 3)
      lat=$(Calc "($(echo $lat | cut -c1-2)+$(echo $lat | cut -c3-)/60)")
      if [ $(echo "$message" | cut -d, -f 4) == "S" ]; then lat=-$lat; fi

      long=$(echo "$message" | cut -d, -f 5)
      long=$(Calc "($(echo $long | cut -c1-3)+$(echo $long | cut -c4-)/60)")
      if [ $(echo "$message" | cut -d, -f 6) == "W" ]; then long=-$long; fi

      # nach https://www.movable-type.co.uk/scripts/latlong.html:
      #a=$(Calc "sin(($lat-$oldlat)/2)^2+sin(($long-$oldlong)/2)^2*cos($lat)*cos($oldlat)")
      #dist=$(Calc "6371000*2*atan2(sqrt($a),sqrt(1-$a))");
      # Vereinfachung Pythagoras, ok fuer kleine Abstaende:
      dist=$(Calc "6371000*sqrt(($lat-$oldlat)^2+($long-$oldlong)^2)/180*3.1415926")

      #printf "\033[1K\rold: %.8f %.8f, new: %.8f %.8f, dist: %.8f" "$oldlat" "$oldlong" "$lat" "$long" "$dist"

      if [ $(awk "BEGIN{if ($dist>$thresdist) print 1;else print 0}") == 1 ]; then
        zeit=$(echo "$message" | cut -d, -f 2)
        alt=$(echo "$message" | cut -d, -f 10)
        gs=$(echo "$message" | cut -d, -f 12)
        # datum=$(echo "$message" | cut -d, -f 10)
        mosquitto_pub -h localhost -t womo/RUT955/gps -m "$zeit,$lat,$long,$alt,$gs"
        oldlat=$lat
        oldlong=$long
      fi
      sleep 1
    fi

  done <$backpipe
}

usage() {
  echo "GPS 2 Mqtt"
  echo "send position of GPS messages of type GPRMC via mqtt"
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
