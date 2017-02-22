#!/usr/bin/python

import re
import time
from os import stat
import httpagentparser
import pygeoip
import sys
import logging
import logging.handlers

nginx_log="/tmp/access.log"
syslog_host="10.1.0.107"
syslog_port=5514

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)
handler = logging.handlers.SysLogHandler(address = (syslog_host,syslog_port))
#formatter = logging.Formatter('%(module)s.%(funcName)s: %(message)s')
#handler.setFormatter(formatter)
log.addHandler(handler)

gi = pygeoip.GeoIP('/usr/share/GeoIP/GeoIP.dat')
gic = pygeoip.GeoIP('/usr/share/GeoIP/GeoIPCity.dat')

while True:
    try:
        logfile = open(nginx_log,"r")
    except IOError:
        print "IO Error"
        time.sleep(5)
        continue

    logfile.seek(0,2)
    while True:
        current_position = int(logfile.tell())
        file_size = stat(nginx_log).st_size
        #print "file_size: %s" % file_size
        #print "pos: %s " % current_position
        if current_position > file_size:
            #print "truncated"
            break
                
        line = logfile.readline()
        if not line:
            time.sleep(0.1)
            continue

        # only send the url with html or '/'
        if re.search("GET \/ HTTP|html ", line):
            myline=line.split('|')
            try:
                clientip=myline[-2].strip()
            except:
                continue
            #print clientip
            user_agent=myline.pop()
            myline=map(str.strip, myline)
            agent_info=httpagentparser.detect(user_agent)
            try:
                country = '"' + gi.country_name_by_addr(clientip) + '"'
            except:
                country='"N/A"'

            try:
                if gic.record_by_addr(clientip)['city']:
                    city = '"' + gic.record_by_addr(clientip)['city'] + '"'
                else:
                    city = '"N/A"'
            except:
                city='"N/A"'

            try:
                os= '"' + agent_info['platform']['name'] + '"'
            except:
                os='"N/A"'

            try:
                device = '"' + agent_info['dist']['name'] + '"'
            except:
                device = '""'

            try:
                browser = '"' + agent_info['browser']['name'] + '"'
            except:
                browser = '"N/A"'

            myline.append(os)
            myline.append(device)
            myline.append(browser)
            myline.append(country)
            myline.append(city)
            try:
                final_line =  " ".join(myline)
                #print final_line
                # don't  send search bot access
                if not agent_info['bot']:
                    log.debug(final_line)
            except:
                pass
