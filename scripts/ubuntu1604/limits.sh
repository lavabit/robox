#!/bin/bash -eux

# Determine what type of box this will become, and if we should increase the default user limits.
if [[ "$PACKER_BUILD_NAME" =~ ^(lineage|lineageos)-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  export LIMIT_FILE="50-lineage.conf"
elif [[ "$PACKER_BUILD_NAME" =~ ^magma-.*$ ]]; then
  export LIMIT_FILE="50-magma.conf"
else
  exit 0
fi

# Find out how much RAM is installed, and what 50% would be in KB.
TOTALMEM=`free -k | grep -E "^Mem:" | awk -F' ' '{print $2}'`
HALFMEM=`echo $(($TOTALMEM/2))`

# Setup the memory locking limits.
printf "*    soft    memlock   $HALFMEM\n" > /etc/security/limits.d/$LIMIT_FILE
printf "*    hard    memlock   $HALFMEM\n" >> /etc/security/limits.d/$LIMIT_FILE

# Setup higher file/stack limits.
printf "*    soft    nofile    65536\n" >> /etc/security/limits.d/$LIMIT_FILE
printf "*    hard    nofile    65536\n" >> /etc/security/limits.d/$LIMIT_FILE
printf "*    soft    stack     65536\n" >> /etc/security/limits.d/$LIMIT_FILE
printf "*    hard    stack     65536\n" >> /etc/security/limits.d/$LIMIT_FILE