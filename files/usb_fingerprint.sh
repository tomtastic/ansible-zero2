#!/bin/bash
# Analyze USB Setup Request

# ! Note that dwc2 module needs the following patch for this to work !

# 80 means device to host (bmRequestType)
# 06 means get descriptors (bRequest)
# 03xx means string descriptors (wValue)
# 0409 means english (wIndex)
# wLength is the size of the descriptor and this is what we want

LOGFILE=/home/pi/usbreq.log
dmesg | grep "USB DWC2 REQ 80 06 03" > $LOGFILE

WLENGTHS=$(awk '$9!="0000" { print $10 }' $LOGFILE)
TOTAL=0
COUNTER=0

for i in $WLENGTHS; do
    if [[ "$i" = "00ff" ]]; then
        COUNTER=$((COUNTER+1))
    fi
    TOTAL=$((TOTAL+1))
done
if [[ $TOTAL -eq 0 ]]; then
    echo "Unknown"
    exit
fi
if [[ $COUNTER -eq 0 ]]; then
    echo "MacOS"
else
    echo "Other"
fi
