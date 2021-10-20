#!/bin/bash
#
#
function print_usage {
if [ -n "$PRINT_USAGE" ]; then
   echo "$PRINT_USAGE"
fi
}

function err_exit {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   else
      print_usage
   fi
   exit 1
}

function warn_msg {
   if [ -n "$1" ]; then
      echo "[i] Warning: $1"
   fi
}

function info_msg {
   if [ -n "$1" ]; then
      echo "[i] Notice: $1"
   fi
}

function log_output {
    [ -z "$NOLOG" ] && NOLOG=0
    DATE=$(date '+%m-%d-%y_%H:%M:%S')
    HOSTNAME=$(uname -n)
    [ -z "$LOGFILE" ] && LOGFILE=/tmp/$(basename $0).log
    while read line; do
        [ -z "$line" ] && continue
        if [ "$NOLOG" -eq 0 -a -n "$LOGFILE" ]; then
           echo "$DATE $HOSTNAME: $line" >> $LOGFILE
        else
           echo "$DATE $HOSTNAME: $line"
        fi
    done
}

function prep_generic {
  local DATE=$(date +%m%d%y_%H%M)
  echo "Starting general prep steps on $DATE."
}

function cb_install {
  local DATE=$(date +%m%d%y_%H%M)
  echo "Starting Couchbase server install steps on $DATE."
}
