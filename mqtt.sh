#!/bin/sh
###################
# MQTT Shell Logger

outputdir="/mnt/mmcblk0p1"
filenameprefix="log_"
filenamesuffixformat="+%Y-%m-%dT%H_%M_%S%z" # format string for date command
fileextension="csv"
#minfreespace=31149644 # in KiB (for testing)
minfreespace=2097 # in KiB
#maxfilesize=1048 # in B (for testing)
maxfilesize=1048576 # in B

p="/tmp/backpipe";
pidfile="/tmp/pidfile"

ctrl_c() {
  echo "Cleaning up..."
  pid=$(cat $pidfile)
  rm -f $p
  rm -f $pidfile  
  kill $pid 2>/dev/null
  if [[ "$?" -eq "0" ]];
  then
     echo "Exit success";exit 0
  else
     exit 1
  fi
}

listen(){

  ([ ! -p "$p" ]) && mkfifo $p
  (mosquitto_sub -v $*>$p 2>/dev/null) &
  echo "$!" > $pidfile

  while read line <$p
  do

    #timestamp=$(date -Ins)                      # option ns not available on busybox
    ns=$(adjtimex | awk 'NR==12 {print $NF}')    # get nanoseconds on busybox
    timestamp=$(date "+%Y-%m-%dT%H:%M:%S.$ns%z") # workaround for not having +%N or -Ins options in date
    #timestamp=$(date "+%Y-%m-%dT%H:%M:%S%z")    # give up on nanoseconds
    
    topic=${line%%" "*}
    message=${line#*" "}

    # debugging:
    #echo "topic: "$topic
    #echo "message: "$message

    # new file if nessesary:
    #filesize=$(wc -c "$filename")
    #filesize=${filesize%%" "*}
    ([ -z "$filename" ] || \
    (filesize=$(wc -c "$filename") && filesize=${filesize%%" "*} && [ "$filesize" -gt "$maxfilesize" ])) && \
    filename="$outputdir/$filenameprefix$(date $filenamesuffixformat).$fileextension"
    
    # delete oldest, if nessesary:
    avail=$(df "$outputdir" | awk 'NR == 2 { print $4 }') # get free disk space
    [ "$avail" -lt "$minfreespace" ] && rm "$(ls $outputdir/log_* -ltr | grep -v '^d' | awk 'NR==1 {print $NF; exit}')"

    # write log entry:
    echo "\"$timestamp\",\"$topic\",\"$message\"">>"$filename"

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

