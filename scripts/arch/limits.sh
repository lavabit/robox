#!/bin/bash -eux

# Find out how much RAM is installed, and what 50% would be in KB.
TOTALMEM=`free -k | grep -E "^Mem:" | awk -F' ' '{print $2}'`
HALFMEM=`echo $(($TOTALMEM/2))`

# Setup the memory locking limits.
printf "*    soft    memlock    $HALFMEM\n" >> /etc/security/limits.conf
printf "*    hard    memlock    $HALFMEM\n" >> /etc/security/limits.conf
