# $language = "Python"
# $interface = "1.0"

import os,re,sys

# Connect to multiple servers via a session.
# SecureCRT session name
connect_session="EC/lb"
server_list='/Users/usr/SecureCRT/server.txt'
default_port='22'
default_pass='123456'
sudo_wanted=False
sudo_need_pass=True

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
             except:
                 password = default_pass
    
             ssh_command="ssh -o 'StrictHostKeyChecking no' -o 'PreferredAuthentications=publickey,password' " + user + "@" + server + " -p " + port
    
             # connect to securecrt session
             try:
                 crt.Session.ConnectInTab("/s " + connect_session);
             except ScriptError:
                 error = crt.GetLastErrorMessage()
                 return
    
             count=crt.GetTabCount()
             objTab = crt.GetTab(count)    
             objTab.Screen.Synchronous = True
             objTab.Screen.IgnoreEscape = True
             
             objTab.Screen.Send(ssh_command + "\r")
             szOutput = objTab.Screen.ReadString(["$","password: ","refused","reset"], 6)
    
             # MatchIndex: Determines which index within your list of strings was found by the ReadString or WaitForStrings method.
             # A MatchIndex value of 0 indicates that a timeout occurred before a match was found
             connection_index = objTab.Screen.MatchIndex
             if (connection_index== 0):
                 # connection timeout 
                 crt.Dialog.MessageBox("Connection Timed out: " + server)
             elif (connection_index== 1):
                 # login as a normal user with publickey successfully
                 if sudo_wanted:                 
                     if sudo_need_pass:
                         objTab.Screen.Send("sudo su - \r")
                         objTab.Screen.WaitForString(user+":")
                         objTab.Screen.Send(password+"\r")
                     else:
                         objTab.Screen.Send("sudo su - \r")
             elif (connection_index== 2):
                 # connected and password required 
                 objTab.Screen.Send(password+"\r")
                 
                 # check password
                 szOutput2 = objTab.Screen.ReadString(["$","try again","# "], 6)
                 login_index = objTab.Screen.MatchIndex
    
                 # no response in 5 seconds
                 if (login_index == 0):
                     crt.Dialog.MessageBox("No response from server: " + server)
                 elif (login_index == 1):
                     # login as a normal user with password successfully 
                     if sudo_wanted:                 
                         if sudo_need_pass:
                             objTab.Screen.Send("sudo su - \r")
                             objTab.Screen.WaitForString(user+":")
                             objTab.Screen.Send(password+"\r")
                         else:
                             objTab.Screen.Send("sudo su - \r")
                 elif (login_index == 2):
                     # invalid password 
                     crt.Dialog.MessageBox("Invalid password. " + server)
                     pass
                 elif (login_index == 3):
                     pass
             elif (connection_index== 3 or connection_index== 4):
                  # ssh connection refused
                  crt.Dialog.MessageBox("Connection refused " + server)
             objTab.Screen.Synchronous = False
                  
main()
