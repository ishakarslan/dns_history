PATH="$PATH:/scripts"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

###### VARS ######
SCRIPTPATH="/scripts"
MAINPATH="/data/fqdn_ips"
SCANPATH="/data/fqdn_ips/rawresult"
PARSERPATH="/data/fqdn_ips/work"
RESULTPATH="/data/fqdn_ips/result"
BULKPATH="/data/fqdn_ips/bulk"
LOGDIR="/var/log/fqdn_ips-`date +'%Y-%m-%d'`.log"
###### END VARS #####

check_es_job () {
COMMAND=`ssh user@elastic_ip 'cat /scripts/lock/fqdn_ips.lock'`
if [[ $COMMAND == 0 ]]
   then
      echo 0
   else
      echo 1
fi
}

echo "`date +'%Y-%m-%d %T'` starting massdns" >> $LOGDIR

#Clear temporary files

if [ -n  "$(find $SCANPATH/ -type f)" ]
then
    rm -f $SCANPATH/*
else
    echo "`date +'%Y-%m-%d %T'` rawresult already deleted" >> $LOGDIR
fi



#Delete the scan result from the previous day

if [ ! -f $RESULTPATH/result-today ]
then
    echo "`date +'%Y-%m-%d %T'` result-today file couldn't find" >> $LOGDIR
else
    rm -f $RESULTPATH/result-yester
fi

###Son tarama sonucunu rename et
if [ -f $RESULTPATH/result-today ]
then
    mv $RESULTPATH/result-today $RESULTPATH/result-yester
else
    echo "`date +'%Y-%m-%d %T'` result-today ..couldn't find, please check it" >> $LOGDIR
    exit 0
fi

#Run massdns
/usr/local/bin/massdns --retry REFUSED --retry SERVFAIL -q  --processes 10 -r /root/massdns/lists/resolvers.txt -t A -o Snq /data/fqdn_ips/2019-04-fqdns.txt  -w /data/fqdn_ips/rawresult/fqdn_ip.txt --root -c 100

if [ $? -eq 0 ]
then
    echo "`date +'%Y-%m-%d %T'` fqdns_ips ip dns query process is finished" >> $LOGDIR
else
    echo "`date +'%Y-%m-%d %T'` fqdn_ips query: There is an error,please check it!!" >> $LOGDIR
    exit 0
fi

#Run Parser
cd $MAINPATH
LC_LLC=C grep -h "$" $SCANPATH/*| \
    awk '$2 !~ /[A-Za-z]/' | \
    awk 'NR!=1 && p1!=$1{print prev;prev=""}{p1=$1;prev=(prev"")?prev FS substr($0,index($0,$2)):$0}END{if(prev"") print prev}'|\
    awk '{print tolower($0)}'|\
    sed -e 's/.  /, /' |sed 's/, $/, 0.0.0.0/' |sed 's/,  \S*\. /,  /' |sed  's/^/aaaaa-/'|\
    awk '{split($0,a);asort(a);for(i=NF;i>0;i--){printf("%s ",a[i])}print ""}'|\
    sed 's/^aaaaa-//' > $RESULTPATH/result-today

if [ $? -eq 0 ]
then
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip parsing is finished" >> $LOGDIR
else
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip parsing error, please check it" >> $LOGDIR
   exit 1
fi


#compare yesterday's and today's results

mawk 'NR==FNR {exclude[$0];next} !($0 in exclude)' $RESULTPATH/result-yester $RESULTPATH/result-today|sed 's/, $/, 0.0.0.0/' > $RESULTPATH/result

if [ $? -eq 0 ]
then
  echo "`date +'%Y-%m-%d %T'` Compare finished" >> $LOGDIR
else
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip compare error, please check it" >> $LOGDIR
   exit 0
fi

##check elasticsearch job status, if yesterday's process is finished, go ahead else wait

while [ `check_es_job` -ne 0 ]
do
    sleep 300
done

/scripts/fqdn_ips/update_es.sh > /dev/null 2>&1 &

if [ $? -eq 0 ]
then
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip job finished" >> $LOGDIR
else
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip job error, please check it" >> $LOGDIR
fi
exit 0
