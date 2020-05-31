#!/bin/sh
###################
# MQTT Shell Logger

outputroot="/mnt/mmcblk0p1" # Scope to put and rotate the logs in, thus oldest file inside this might get deleted, even if not lyed out by this script!
outputsubdirs=1             # whether to create subdirectories for each topic
filenameprefix="log_"
filenamesuffixformat="+%Y-%m-%dT%H_%M_%S%z" # format string for date command
fileextension="csv"
#minfreespace=31149460 # in KiB (for testing)
minfreespace=2097 # in KiB
#maxfilesize=1048 # in B (for testing)
maxfilesize=1048576 # in B

backpipe="/tmp/mqttlogger_backpipe"
pidfile="/tmp/mqttlogger_pidfile"

ctrl_c() {
  echo "Cleaning up..."
  kill $(cat $pidfile)  2>/dev/null
  rm -f $backpipe $pidfile
  [ "$?" -eq "0" ] && { echo "Exit success"; exit 0; } || exit 1
}

listen(){

  [ ! -p "$backpipe" ] && mkfifo $backpipe
  (mosquitto_sub -v $*>$backpipe 2>/dev/null) &
  echo "$!" > $pidfile

  while read line <$backpipe
  do

    #timestamp=$(date -Ins)                      # option ns not available on busybox
    ns=$(adjtimex | awk 'NR==12 {print $NF}')    # get nanoseconds on busybox
    timestamp=$(date "+%Y-%m-%dT%H:%M:%S.$ns%z") # workaround for not having +%N or -Ins options in date
    #timestamp=$(date "+%Y-%m-%dT%H:%M:%S%z")    # give up on nanoseconds

    topic=${line%%" "*}
    message=${line#*" "}
    outputpath="$outputroot"$([ $outputsubdirs -ne 0 ] && echo "/$topic")

    # make new directory if necessary
    # otherwise get last changed logfile inside the subfolder
    [ ! -d $outputpath ] && { mkdir -p $outputpath; unset filename; } || \
    filename=$(find $outputpath -maxdepth 1 -type f -name "$filenameprefix*.$fileextension" -print0 | xargs -0r ls -t | head -n1)

    # debugging:
#    echo "topic=$topic"
#    echo "message=$message"
#    echo "outputpath: $outputpath"

    # new file if necessary:
    ([ -z "$filename" ] || \
    (filesize=$(wc -c "$filename") && filesize=${filesize%%" "*} && [ "$filesize" -gt "$maxfilesize" ])) && \
    filename="$outputpath/$filenameprefix$(date $filenamesuffixformat).$fileextension"

    # delete oldest, if necessary:
    avail=$(df "$outputroot" | awk 'NR == 2 { print $4 }') # get free disk space
    [ "$avail" -lt "$minfreespace" ] && rm "$(find $outputroot -type f -name "$filenameprefix*.$fileextension" -print0 | xargs -0r ls -tr | head -n1)"

    # write log entry:
    echo "\"$timestamp\"$([ $outputsubdirs -eq 0 ] && echo ",\"$topic\""),\"$message\"">>"$filename"

  done
}

usage(){
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
trap ctrl_c INT
listen $*
;;
esac

