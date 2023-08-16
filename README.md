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

**fqdn_ips.sh**





