# $language = "Python"
# $interface = "1.0"

import os,re,sys

server_list='/Users/usr/SecureCRT/server.txt'
default_port='22'
default_pass='123456'

def main():

    try:
        file = open(server_list)
    except:
        print "[ERROR]: Failed to open server list : " + server_list
        crt.Dialog.MessageBox("[ERROR]: Failed to open server list : " + server_list)
        return

    for line in file:
        info = line.strip()
        if info and not info.startswith('#'): 
             try:
                 user = info.split(':')[0]
                 server = info.split(':')[1]
                 port = info.split(':')[2]
                 if port == "":
                     port = default_port
             except:
                 port = default_port
                 
             try:
                 password = info.split(':')[3]
                 if not password:
                     password = default_pass
             except:
                 password = default_pass
             
             ssh_command="/SSH2 /PASSWORD " + password + " " + user + "@" + server

             try:
                 crt.Session.ConnectInTab(ssh_command, True)
             except ScriptError:
                 # errcode = crt.GetLastError()
                 crt.Dialog.MessageBox(server + " : Connection Failed")
                 continue

             count=crt.GetTabCount()
             objTab = crt.GetTab(count)    
             objTab.Screen.Synchronous = True
             objTab.Screen.IgnoreEscape = True
             
             # server ready 
             objTab.Screen.WaitForString("]")

main()
