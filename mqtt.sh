#!/bin/sh
###################
# MQTT Shell Logger

temp_dir=$(mktemp -d)

mkfifo "$temp_dir/out" "$temp_dir/err"
<"$temp_dir/out" logger -p user.notice -t "$(basename "$0")" &
<"$temp_dir/err" logger -p user.error -t "$(basename "$0")" &
exec >"$temp_dir/out" 2>"$temp_dir/err" 

outputroot="/mnt/mmcblk0p1" # Scope to put and rotate the logs in, thus oldest file inside this might get deleted, even if not lyed out by this script!
outputsubdirs=1             # whether to create subdirectories for each topic
filenameprefix="log_"
filenamesuffixformat="+%Y-%m-%dT%H_%M_%S%z" # format string for date command
fileextension="csv"
#minfreespace=31149460 # in KiB (for testing)
minfreespace=2097 # in KiB
#maxfilesize=1048 # in B (for testing)
maxfilesize=1048576 # in B

backpipe="$temp_dir/mqttlogger_backpipe"
pidfile="$temp_dir/mqttlogger_pidfile"

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
  (mosquitto_sub $* 1>$backpipe) &
  echo "$!" >"$pidfile"

  echo "connected."
  
  while read line; do

    # get nanoseconds on busybox
    # (workaround for not having +%N or -Ins options in date)
    us=$(adjtimex | awk 'NR==12 {print $NF}')
    timestamp=$(date "+%Y-%m-%dT%H:%M:%S.$us%z")

    topic=${line%%" "*}
    message=${line#*" "}
    outputpath="$outputroot"$([ $outputsubdirs -ne 0 ] && echo "/$topic")

    # make new directory if necessary
    # otherwise get last changed logfile inside the subfolder
    [ ! -d $outputpath ] && {
      mkdir -p $outputpath
      unset filename
    } ||
      filename=$(find $outputpath -maxdepth 1 -type f -name "$filenameprefix*.$fileextension" -print0 | xargs -0r ls -t | head -n1)

    # debugging:
    # echo "received: $topic = $message"
    # echo "outputpath: $outputpath"

    # new file if necessary:
    ([ -z "$filename" ] ||
      (filesize=$(wc -c "$filename") && filesize=${filesize%%" "*} && [ "$filesize" -gt "$maxfilesize" ])) &&
      filename="$outputpath/$filenameprefix$(date $filenamesuffixformat).$fileextension"

    # delete oldest, if necessary:
    avail=$(df "$outputroot" | awk 'NR == 2 { print $4 }') # get free disk space
    [ "$avail" -lt "$minfreespace" ] && rm "$(find $outputroot -type f -name "$filenameprefix*.$fileextension" -print0 | xargs -0r ls -tr | head -n1)"

    # write log entry:
    echo "$timestamp$([ $outputsubdirs -eq 0 ] && echo ",$topic"),$message" >>"$filename"

  done <$backpipe
}

usage() {
  echo "Mqtt-Exec Logger Via Bash"
  echo "based on https://unix.stackexchange.com/a/274224"
  echo "Logger writes messages from subscribed topics into a file."
  echo "Usage: $0 [options]"
  echo "same options like for mosquitto_sub. '-v' gets added"
  echo "Configure output directory and other parameters inside script."
}

case "$1" in
--h)
  usage
  exit 1
  ;;
*)
  trap ctrl_c INT TERM QUIT
  listen -v -t womo/# $*
  ;;
esac
