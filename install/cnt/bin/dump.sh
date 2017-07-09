#!/bin/sh
SETUP_FILE=/cnt/setup-ds.inf
FILE=$1

if [ ! -f "$SETUP_FILE" ]; then
  echo "$SETUP_FILE does not exist. Exit"
  exit 1
fi

SERVER_ID=$(grep "^ServerIdentifier=" $SETUP_FILE|sed s/^ServerIdentifier=//)
SUFFIX=$(grep "^Suffix=" $SETUP_FILE|sed s/^Suffix=//)

#echo $SERVER_ID
#echo $SUFFIX
if [ -z "$FILE" ]; then
  FILE="/tmp/$$.userRoot.ldif"
fi
LOG=export.log
ns-slapd db2ldif -D /etc/dirsrv/slapd-$SERVER_ID -s $SUFFIX -a $FILE 2>$LOG
RET=$?
if [ ! $RET == 0 ]; then
  cat $LOG
  exit $RET
fi
cat $FILE
rm -f $FILE
