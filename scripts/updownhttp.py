import urllib.request
import urllib.error
import time
import sys
import socket
from multiprocessing import Pool

start = time.time()

#file = open("xaa", "r", encoding="ISO-8859-1")
file = open(sys.argv[1], 'r', encoding="ISO-8859-1")
urls = file.readlines()
#k = open("file.txt","w+")
#print(urls)


def checkurl(url):
    f = open("/scripts/updown/result/result-today", "a+")
    try:
        conn = urllib.request.urlopen(url, timeout=3)
    except urllib.error.HTTPError as e:
        # Return code error (e.g. 404, 501, ...)
        urlx = str(url.replace('http://', '')).rstrip()
        codex = str(e.code).rstrip()
        f.write("{1}, {0}\n".format(codex, urlx))
    except urllib.error.URLError as e:
        # Not an HTTP-specific error (e.g. connection refused)
        urlx = str(url.replace('http://', '')).rstrip()
        codex = str(e.reason).rstrip()
        timeout = "1"
        dnserr = "2"
        if isinstance(e.reason, socket.timeout):
            f.write("{1}, {0}\n".format(timeout, urlx))
        elif isinstance(e.reason, socket.gaierror):
            f.write("{1}, {0}\n".format(dnserr, urlx))
    except:
        othererr = "0"
        urlx = str(url.replace('http://', '')).rstrip()
        f.write("{1}, {0}\n".format(othererr, urlx))
        #pass
    else:
        # Status code (e.g. 200, 302, ...)
        urlx = str(url.replace('http://', '')).rstrip()
        codex = str(conn.code).rstrip()
        f.write("{1}, {0}\n".format(codex, urlx))
#    f.close()
if __name__ == "__main__":
    p = Pool(processes=900)
    result = p.map(checkurl, urls)
#    for i in urls:
#        checkurl(i)

#print("done in : ", time.time()-start)
