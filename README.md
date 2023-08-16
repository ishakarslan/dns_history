## dns_history
### Aim
There are about 500m domains and 650M fqdns in the world,  Within the scope of the project, it is aimed to check and keep DNS history of all fqdns and domains every day and update them on a nosql database,  monitor http/https up/down status historically.

It includes querying A, NS, MX, and TXT records on FQDN and Domain lists at desired periods, comparing the obtained data with the previous query and historically processing the changed records.

### Tools Used
- Massdns
- Bash
- Python3
- Awk/Mawk
- Curl
- Elasticsearch

### Query Scripts
- A records      : /scripts/fqdns_ips/fqdn_ips.sh
- NS records     : /scripts/fqdn_ips/fqdn_ns.sh
- MX records     : /script/fqdn_ips/fqdn_mx.sh
- SPF records    : /scripts/fqdn_ips/fqdn_spf.sh

When you run the scripts it will query the result using massdns and write the raw results to text files
- A results      : /data/fqdns_ips/rawresult
- NS results     : /data/fqdn_ips/rawresultns
- MX results     : /data/fqdn_ips/rawresultmx
- SPF results    : /data/fqdn_ips/rawresultspf

Then the parser will parse the raw result and write parsed results to text files
- A results      : /data/fqdns_ips/result
- NS results     : /data/fqdns_ips/resultns
- MX results     : /data/fqdns_ips/resultmx
- SPF results    : /data/fqdns_ips/resultspf

Since I did not have the resources to make millions of queries to the db, I worked in text files, awk is very successful for comparing millions of results in an hour.

### Using Scripts

***fqdn_ips.sh***

```#!/bin/bash 

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

/scripts/fqdn_ips/start_fqdn.sh > /dev/null 2>&1 &

if [ $? -eq 0 ]
then
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip job finished" >> $LOGDIR
else
   echo "`date +'%Y-%m-%d %T'` fqdns_ips ip job error, please check it" >> $LOGDIR
fi
exit 0
```

The script is processing some files before it starts working,
First of all, it cleans the raw dns queries of the previous day, deletes the raw query results of yesterday under the /data/fqdn_ips/rawresult/ directory, makes it ready for today's results to be written,
Then it removes the “result-yester” file in the /data/fqdn_ips/result directory, this file contains the processed results from two days ago,
Finally, it replaces the "result-today" file in the /data/fqdn_ips/result directory as "result-yester", so today's parsed results will be written as "result-today" again and  will be compared with yersterday's results, then changed fqdn/domains will be written to the  "result" file. This method has been started because comparing  changed dns records from elasticsearch will  tire elasticsearch and take too much time.

### Massdns
https://github.com/blechschmidt/massdns
I changed massdns codes and will upload github, it was more difficult to parse massdns results, I changed the massdns output, the output like below

<img width="628" alt="Screenshot 2023-08-16 at 14 21 39" src="https://github.com/ishakarslan/dns_history/assets/5375225/fe82c0b8-d672-429c-baa6-585f4e2a84d5">

when I upload it you should download it and compile it

```cd massdns && make && make install```

### Using massdns
```/usr/local/bin/massdns --retry REFUSED --retry SERVFAIL -q  --processes 10 -r /root/massdns/lists/resolvers.txt -t A -o Snq /data/fqdn_ips/2019-04-fqdns.txt  -w /data/fqdn_ips/rawresult/fqdn_ip.txt --root -c 100```

### description of parameters
- retry REFUSED   : If a resolver connection refused is returned for a query, ask another resolver.
- retry SERVFAIL  : if the resolver returns SRVFAIL(incorrect dns record) for a query, ask another resolver.
- q               : print output to stdout.
- precesses       : the number of processes to open.
- /root/massdns/lists/resolvers.txt : list of resolvers to use.
- t               : query type.
- o               : output format (this format is customized).
- /data/fqdn_ips/2019-04-fqdns.txt : fqdn list to ask.
-w                : the destination where the output will be written (here, each process creates its own output file in the target directory, eg: fqdn_ip.txt0, fqdn_ip.txt1, fqdn_ip.txt2, each process appends its id to the end of the file)

### Createing Massdns resolver list
Massdns resolver list is provided from public-dns.info address, a script has been prepared for sinkhole or resolvers that return different answers, this script located /root/massdns/lists/test.sh, a domain given to the script is asked to all resolvers and those that return different answers are eliminated, The script content is as follows;

```
for i in `cat /root/massdns/lists/resolvers.txt`
do
  echo -e "$i\t\t`dig +short +time=3  homeapps.esignal.com @$i|sed -e :a -e '$!N; s/\n/ /; ta'`\n"
done
```








