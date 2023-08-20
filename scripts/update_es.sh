#!/bin/bash

PATH="$PATH:/scripts"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

###### VARS ######
SCRIPTPATH="/scripts/fqdn_ips"
MAINPATH="/data/fqdn_ips"
SCANPATH="/data/fqdn_ips/rawresult"
PARSERPATH="/data/fqdn_ips/work"
RESULTPATH="/data/fqdn_ips/result"
BULKPATH="/data/fqdn_ips/bulk"
LOGDIR="/var/log/fqdn_ips-`date +'%Y-%m-%d'`.log"
###### END VARS #####

echo "1" > /scripts/lock/fqdn_ips.lock

echo "`date +'%Y-%m-%d %T'` creating bulk files" >> $LOGDIR

rm -f $BULKPATH/*

cd $SCRIPTPATH && python3 fqdn_ip.py 2 >> $LOGDIR

##get result file and split for bulk insert
cd $BULKPATH && split -l 80000 blk.txt

echo "`date +'%Y-%m-%d %T'` compare process finished and bulk files created" >> $LOGDIR
echo "`date +'%Y-%m-%d %T'` insert bulk files to es" >> $LOGDIR

##Update es
cd $BULKPATH && \
    for i in $(ls xa* xb* xc* xd* xe* xf* xg*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
    for i in $(ls xh* xi* xj* xk* xl* xm* xn*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
    for i in $(ls xo* xp* xq* xr* xs* xt* xu*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
    for i in $(ls xv* xw* xx* xy* xz*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
echo "`date +'%Y-%m-%d %T'` es update job finished" >> $LOGDIR

echo "0" > /scripts/lock/fqdn_ips.lock
exit 0
