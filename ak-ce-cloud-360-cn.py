#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Description:
#     * send task to http://ce.cloud.360.cn/ and fetch the result (website check or ping check).
# Usage:
#     * ak-ce-cloud-360-cn.py get  <url>
#     * ak-ce-cloud-360-cn.py ping <domain>

import simplejson
import requests
import pygeoip
import re
import os
import time

# fix 'ascii' codec can't encode characters in position 0-2: ordinal not in range(128)
import sys
reload(sys)
sys.setdefaultencoding( "utf-8" )

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[0;32m'
    WARNING = '\033[1;33m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

#
wait_time = 30
total_node_count=0
ok_node_count=0
url = 'http://ce.cloud.360.cn/'
url_task='http://ce.cloud.360.cn/task'
url_detect="http://ce.cloud.360.cn/Tasks/detect"
token1=''
token2=''

if os.path.exists("/etc/redhat-release"):
    home_dir="/usr/share/GeoIP/"
else:
    home_dir="/usr/local/var/GeoIP/"

country_data=home_dir + "GeoLiteCountry.dat"
city_data=home_dir + "GeoLiteCity.dat"
asnum_data=home_dir + "GeoIPASNum.dat"

# GEOIP
try:
    gict = pygeoip.GeoIP(country_data)
    gic = pygeoip.GeoIP(city_data)
    gia = pygeoip.GeoIP(asnum_data)
except Exception as e:
    print "Failed to load IP data: " + str(e)
    sys.exit(1)

def get_location(target_ip):
    info=gic.record_by_addr(target_ip)
    city=info.get('city')
    country=gict.country_code_by_addr(target_ip)
    asnum=gia.org_by_addr(target_ip)
    asnum=re.sub(r'AS\d+\s+','',asnum)
    if not country:
        country = ''
    if not asnum:
        asnum = ''
    if not city:
        city = ''
    return country + "." + city + "." + asnum

# usage
def usage():
    print "Usage: " + sys.argv[0] + " <get|ping> <domain>"
    sys.exit(1)

if len(sys.argv) < 2:
    usage()
else:
    action_type = sys.argv[1]
    if not action_type in ['get','ping']:
        usage()
    domain = sys.argv[2]

# headers
headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.86 Safari/537.36'}
ajax_headers = {
'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.86 Safari/537.36',
'Host': 'ce.cloud.360.cn',
'Origin': 'http://ce.cloud.360.cn',
'X-Requested-With': 'XMLHttpRequest',
'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
'Referer': 'http://ce.cloud.360.cn/task'
}

# text align for Chinese
def myAlign(string, length=0):
    if length == 0:
        return string
    slen = len(string)
    re = string
    if isinstance(string, str):
        placeholder = ' '
    else:
        placeholder = u'　'
    while slen < length:
        re += placeholder
        slen += 1
    return re

# step 1
print "1. Getting http://ce.cloud.360.cn/"
s = requests.Session()
r = s.get(url,headers=ajax_headers)
r.encoding='utf-8'
for i in r.text.split('\n'):
    if re.match('.*__token__.*value="(\w+)"',i):
        m = re.match('.*__token__.*value="(\w+)"',i)
        token1 = m.group(1)
print "First token: " + token1

# step 2
print "2. Getting http://ce.cloud.360.cn/task"
data = { 'type': action_type , 'domain': domain , '__token__' : token1 }
r = s.post(url_task, data=data, headers=ajax_headers, timeout=10)
r.encoding='utf-8'
for i in r.text.split('\n'):
    if re.match('.*__token__.*value="(\w+)"',i):
        m = re.match('.*__token__.*value="(\w+)"',i)
        token2 = m.group(1)
print "Second token: " + token2


# step3
print "3. Sending detect request: " + url_detect
data2={'domain': domain ,'type': action_type, '__token__': token2}
r = s.post(url_detect, data=data2, headers=ajax_headers)

#if r.status_code != '200' and r.text != '1':
if r.status_code != '200' and r.text != '1':
    print "Failed to submit your request." , r.status_code , r.text
    sys.exit(1)

# step4
print "4. Waiting for return data, please wait .",
i=0
while i < wait_time:
    print ".",
    i += 1
    sys.stdout.flush()
    time.sleep(1)
print

print "5. Fetching task summary ..."
summary_url = 'http://ce.cloud.360.cn/GetData/getTaskSummary?domain=' + domain + '&type=' + action_type
r = s.get(summary_url)
c = r.text

# clear screen
os.system('clear')

# load and parse summary
j = simplejson.loads(c,strict=True)

print '-' * 120
print "+++++++++++++++++++++++++++++++++++++++++++++++++++++ Test Result ++++++++++++++++++++++++++++++++++++++++++++++++++++++"
print '-' * 120
for province in j['province_table'].keys():
    if not j['province_table'][province]:
        continue
    for city in j['province_table'][province]['data'].keys():
        for node in j['province_table'][province]['data'][city]:
            try:
                if action_type == 'ping':
                    total_node_count += 1
                    mtime = node['min_time']
                    min_time = str(node['min_time']) + 'ms'
                    avg_time = str(node['avg_time']) + 'ms'
                    max_time = str(node['max_time']) + 'ms'
                    isp = node['isp']
                    ip = node['ip']
                    ip_location = get_location(ip)
                    node_location =  city + "-" + isp
                    node_location=myAlign(node_location, 20)

                    if mtime > 0.01:
                        ok_node_count += 1
                        print "%s | %-15s | %-10s | %-10s | %-10s | %s" % ( node_location,ip, min_time,max_time,avg_time,ip_location)
                    else:
                        print "%s | %-15s | %-10s | %-10s | %-10s | %s" % (  bcolors.WARNING + node_location,ip, min_time,max_time,avg_time,ip_location  + bcolors.ENDC)
                else:
                    total_node_count += 1
                    retcode = node.get('retcode', 'null')
                    if retcode in ['200','301', '302']:
                        ok_node_count += 1
                    conntime = str(node.get('conntime', 'null')) + 'ms'
                    dtime = str(node.get('dtime', 'null')) + 'ms'
                    dsize = str(node.get('dsize', 'null'))
                    isp = node.get('isp', 'null')
                    ip = node.get('ip', 'null')
                    if not ip == 'null':
                        ip_location = get_location(ip)
                        node_location =  city + "-" + isp
                        node_location=myAlign(node_location, 20)
                    else:
                        ip_location = 'null'
                        node_location = 'null'
                    print "%s | %-15s | %-6s | %-12s | %-12s | %-12s | %s" % ( node_location,ip,retcode,conntime,dtime,dsize,ip_location)
                    ok_node_count += 1
            except Exception as e:
                print e

print '-' * 120
print "+ OK Nodes:" + str(ok_node_count)
print "---------------------------------"
print "+ Total Nodes:" + str(total_node_count)
print "---------------------------------"
print "+ Success Rate : %.2f%%" % (float(ok_node_count)/float(total_node_count)*100)
print "---------------------------------"
