import datetime
from elasticsearch import Elasticsearch, helpers
from tld import get_tld, get_fld
import sys
import tldextract
import json
from simplejson import loads, dumps
from multiprocessing import Pool

file = open("/data/fqdn_ips/result/result")
content = file.read().splitlines()

TOTAL = {}
ip_addr_arch = {"ip": "0.0.0.0","insert_date": "1-1-1", "last_seen": "1-1-1"}
es = Elasticsearch([{'host': "10.0.0.182", 'port': "9200"}])

def request_to_es(fqdn):
    res = es.get(index="clear_fqdn_assets2", doc_type='unique', id=fqdn)
#    if res['found'] == True:
    if "ip_addr" in res['_source']:
        return res
    else:
        if_domain_not_exist()

def read_file(input):
    a = input.split(',')
    domain = a[0]
    ips = a[1]
    iplist = ips.split(" ")
    TOTAL[domain] = iplist
    return TOTAL

def request_from_file(domain):
    return TOTAL['{0}'.format(domain)]

def ask_for_duplicate(iplist, ip):
    for i in iplist:
        if i == ip:
            if iplist.count(i) > 1:
                return True
            else:
                return False

def ask_for_lastseen(bulk, ip):
    for i in reversed_list(bulk['ip_addr']):
        if i['ip'] == ip:
            return i['last_seen']

def remove_duplicate(content):
    objs = content
    iplst = []
    for obj in objs:
        if obj not in [obj for obj in iplst]:
            iplst.append(obj)
    return iplst

def reversed_list(alist):
    return alist[::-1]

def first_down(blist, status):
    if status == "down":
        for i in reversed_list(blist):
            if i['ip'] == "0.0.0.0" and i['last_seen'] == "1-1-1":
                return  i['insert_date']
    elif status == "up":
        return "1-1-1"

def first_up(clist, status):
    if status == "down":
        for i in reversed_list(clist):
            if i['ip'] == "0.0.0.0" and i['last_seen'] != "1-1-1":
                return i['last_seen']
                break
    elif status == "up":
        return "1-1-1"

def ip_change_status(checkip):
    last_ip = checkip[-1]
    second_last = checkip[-2]
    if last_ip['ip'] == "0.0.0.0" and last_ip['last_seen'] == "1-1-1":
#        if second_last['ip'] != "0.0.0.0" and second_last['last_seen'] != "1-1-1":
            return "1"
    if last_ip['ip'] != "0.0.0.0":
        for i in checkip:
            if i['ip'] == "0.0.0.0" and i['last_seen'] == datetime.datetime.now().strftime("%Y-%m-%d"):
                return "2"
                break
            else:
                return "3"

def ip_current_status(checkip):
     if checkip == "1":
         return "down"
     else:
         return "up"

def compare():
    blk = open("/data/fqdn_ips/bulk/blk.txt", "a+")
    domain = list(TOTAL.keys())[0]
    bulk_api_headerz = { "update" : { "_index" : "clear_fqdn_assets2", "_type" : "unique", "_id" :domain } }
    try:
        bulk = request_to_es(domain)
        bulk_contentz = bulk['_source']
        ip_counter = int(bulk['_source']['ipcounter'])
        ip_counter += 1
        from_file = request_from_file(domain)
        iplist_from_elasticsearch = []
        for i in bulk['_source']['ip_addr']:
            iplist_from_elasticsearch.append(i['ip'])
        for i in from_file:
            if i is not "":
                if i in iplist_from_elasticsearch and ask_for_lastseen(bulk_contentz, i) == "1-1-1":
                    pass
                else:
                    if ask_for_duplicate(iplist_from_elasticsearch, i) == True and ask_for_duplicate(iplist_from_elasticsearch, i) == False:
                        if ask_for_lastseen(bulk_contentz, i) != "1-1-1":
                            ip_addr_arch = {"ip": "0.0.0.0","insert_date": "1-1-1", "last_seen": "1-1-1"}
                            ip_addr_arch['ip'] = i
                            ip_addr_arch['last_seen'] = "1-1-1"
                    else:
                        ip_addr_arch = {"ip": "0.0.0.0","insert_date": "1-1-1", "last_seen": "1-1-1"}
                        bulk_api_headerz['update']['_id'] = domain
                        ip_addr_arch['ip'] = i
                        ip_addr_arch['insert_date'] = datetime.datetime.now().strftime("%Y-%m-%d")
                        ip_addr_arch['last_seen'] = "1-1-1"
                        bulk_contentz['ip_addr'].append(ip_addr_arch)
        for i in iplist_from_elasticsearch:
            if i in from_file:
                pass
            else:
                for k in bulk_contentz['ip_addr']:
                    if k['ip'] == i and k['last_seen'] == "1-1-1":
                        k['last_seen'] = datetime.datetime.now().strftime("%Y-%m-%d")
                    else:
                         pass
        res = remove_duplicate(bulk_contentz['ip_addr'])
        change_status = ip_change_status(res)
        current_status = ip_current_status(change_status)
        first_up_date = first_up(res, current_status)
        if first_up_date == None:
            first_up_date = "1-1-1"
        if change_status == None:
            change_status = "0"
        totalip = len(bulk_contentz['ip_addr'])
        #zulk = request_to_es(domain)
        bulk_contentz = { "doc" : {"totalip" : totalip, "ipcounter" : ip_counter, "ip_change_status": change_status, "ip_curr_status": current_status, "first_down_date": first_down(res, current_status), "first_up_date": first_up_date, "ip_addr" : res}}
        total_json = (str(bulk_api_headerz).replace("'", '"') + "\n" + str(bulk_contentz).replace("'", '"') + "\n")
        blk.write(total_json)
        #es.bulk(body=total_json)
        blk.close()
    except Exception as e:
        pass

def if_domain_not_exist():
    blk = open("/data/fqdn_ips/bulk/blk.txt", "a+")
    domain = list(TOTAL.keys())[0]
    ext = tldextract.extract(domain)
    tld = ext.suffix
    pld = ext.registered_domain
    totallen = len(request_from_file(domain))
    totalip = totallen - 1
#    bulk_api_headerx = { "index" : { "_index" : "clear_fqdn_assets2", "_type" : "unique", "_id" :domain } }
    bulk_api_headerx = { "update" : { "_index" : "clear_fqdn_assets2", "_type" : "unique", "_id" :domain } }
#    bulk_contentx = { "totalip" : totalip, "fqdn" : domain, "domain": pld, "tld": tld, "@version" : "1", "ttl" : "300", "ip_addr" : [ ], "ipcounter" : "1", "ttlcounter" : "1" }
    bulk_contentx = { "totalip" : totalip, "ip_addr" : [ ], "ipcounter" : "1"}
    from_file = request_from_file(domain)
    for i in from_file:
        if i is not "":
            ip_addr_arch = {"ip": i,"insert_date": datetime.datetime.utcnow().strftime("%Y-%m-%d"), "last_seen": "1-1-1"}
            bulk_contentx['ip_addr'].append(ip_addr_arch)
    bulk_contentx = { "doc" : bulk_contentx}
    total_json = (str(bulk_api_headerx).replace("'", '"') + "\n" + str(bulk_contentx).replace("'", '"') + "\n")
    blk.write(total_json)
    blk.close()
    #es.bulk(body=total_json)

def tain(contentxx):
    try:
        read_file(contentxx)
        compare()
        TOTAL.clear()
    except:
       pass

def compare_with_domain(content):
    read_file(content)
    compare()

#main()
if __name__ == "__main__":
    p = Pool(processes=25)
    result = p.map(tain, content)

