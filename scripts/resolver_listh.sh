for i in `cat /root/massdns/lists/resolvers.txt`
do
  echo -e "$i\t\t`dig +short +time=3  homeapps.esignal.com @$i|sed -e :a -e '$!N; s/\n/ /; ta'`\n"
done
