#!/bin/bash

PATH="$PATH:/scripts"

if [ "$EUID" -ne 0 ]
      then echo "Please run as root"
            exit
        fi

###### VARS ######
        SCRIPTPATH="/scripts"
        MAINPATH="/data/updown"
        RESULTPATH="/data/updown/result"
        BULKPATH="/data/updown/bulk"
        LOGDIR="/var/log/updown-`date +'%Y-%m-%d'`.log"
###### END VARS #####

check_es_job () {
COMMAND=`cat /scripts/lock/updown.lock`
if [[ $COMMAND == 0 ]]
   then
      echo 0
   else
      echo 1
fi
}

###delete yesterday result
if [ ! -f $RESULTPATH/result-today ]
then
    echo "`date +'%Y-%m-%d %T'` relult-today not found" >> $LOGDIR
else
    rm -f $RESULTPATH/result-yester
fi

###Son tarama sonucunu rename et
if [ -f $RESULTPATH/result-today ]
then
    mv $RESULTPATH/result-today $RESULTPATH/result-yester
else
    echo "`date +'%Y-%m-%d %T'` result-today not found, please check it..." >> $LOGDIR
    exit 0
fi

#run job
cd /scripts/updown/domains

for i in `ls a* b* c* d* e* f*`;do python3 ../updown.py $i;done &
for i in `ls g* h* i* j* k* l*`;do python3 ../updown.py $i;done &
for i in `ls m* n* o* p* q* r*`;do python3 ../updown.py $i;done &
for i in `ls s* t* u* v* y* x*`;do python3 ../updown.py $i;done &
for i in `ls z* j*`;do python3 ../updown.py $i;done &

wait

#compare yesterday and today's results

mawk 'NR==FNR {exclude[$0];next} !($0 in exclude)' $RESULTPATH/result-yester $RESULTPATH/result-today|sed 's/, $/, 0/' > $RESULTPATH/result


if [ $? -eq 0 ]
then
  echo "`date +'%Y-%m-%d %T'` compare job finished" >> $LOGDIR
else
   echo "`date +'%Y-%m-%d %T'` updown compare error, please check it...." >> $LOGDIR
   exit 0
fi

##check elasticsearch, if yesterday's job finished go on else wait

while [ `check_es_job` -ne 0 ]
do
    sleep 300
done

#lock the job
echo "1" > /scripts/lock/updown.lock

echo "`date +'%Y-%m-%d %T'` creating updown bulk files" >> $LOGDIR

rm -f $BULKPATH/*

cd $SCRIPTPATH && python3 updown_status.py 2 >> $LOGDIR

##get result file and split it to send elasticsearch
cd $BULKPATH && split -l 80000 blk.txt

echo "`date +'%Y-%m-%d %T'` job finished and bulk files created" >> $LOGDIR
echo "`date +'%Y-%m-%d %T'` sending bulk files to elasticsearch" >> $LOGDIR

##send elastic
cd $BULKPATH && \
    for i in $(ls xa* xb* xc* xd* xe* xf* xg*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
    for i in $(ls xh* xi* xj* xk* xl* xm* xn*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
    for i in $(ls xo* xp* xq* xr* xs* xt* xu*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
    for i in $(ls xv* xw* xx* xy* xz*); do curl -s -H "Content-Type: application/x-ndjson" -XPOST 10.0.0.183:9200/_bulk --data-binary "@$i" > /dev/null; done &
wait
echo "`date +'%Y-%m-%d %T'` updown job is finished" >> $LOGDIR

echo "0" > /scripts/lock/updown.lock
exit 0
