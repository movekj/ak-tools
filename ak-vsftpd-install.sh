#!/bin/bash
 
LOCAL_ROOT="/var/www/sites"
FTP_USERS="test1 test2" 
FTP_GUEST_USER="nginx"

# vsftpd user and pass 
ACCOUNT_LIST="/etc/vsftpd/virtual-users.txt"
 
if [ $EUID -ne 0 ]; then
    echo "[ERROR]: Please run the script with root privileges!"
    exit 1
fi
 
if [ -f "$ACCOUNT_LIST" ]; then
    echo "[ERRROR]: $ACCOUNT_LIST already exist !"
    exit 1
fi

if ! id $FTP_GUEST_USER &>/dev/null; then
    echo "[ERROR]: Invalid ftp guest user: $FTP_GUEST_USER"
    exit 1
fi

if [ ! -d "$LOCAL_ROOT" ]; then
    echo "[ERROR]: Can't find ftp directory: $LOCAL_ROOT"
    exit 1
fi
 
rpm -qi vsftpd db4-utils &>/dev/null
if [ $? -ne 0 ]; then
    echo "[Info]: Start to install vsftpd/db4-utils"
    yum install vsftpd db4-utils -y
fi

# create default vsftpd configuration
cat > /etc/vsftpd/vsftpd.conf << EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_file=/var/log/vsftp.log
xferlog_std_format=YES
vsftpd_log_file=/var/log/vsftpd.log
chroot_list_enable=YES
listen=YES
pam_service_name=vsftpd-virtual
userlist_deny=NO
userlist_enable=YES
tcp_wrappers=YES
guest_enable=YES
virtual_use_local_privs=YES
local_root=$LOCAL_ROOT
chroot_local_user=YES
hide_ids=YES
anon_other_write_enable=YES
user_config_dir=/etc/vsftpd/user_conf
guest_username=$FTP_GUEST_USER
local_umask=002
pasv_enable=YES
#pasv_address=IP_ADDRESS_OF_FIREWALL
#pasv_min_port=33300
#pasv_max_port=33338
EOF
 
mkdir -p /etc/vsftpd/user_conf
useradd -s /sbin/nologin -M ftpvirtual &>/dev/null
gpasswd -a $FTP_GUEST_USER ftpvirtual &>/dev/null
 
cat > /etc/vsftpd/user_list <<EOF
# vsftpd userlist
# If userlist_deny=NO, only allow users in this file
# If userlist_deny=YES (default), never allow users in this file, and
# do not even prompt for a password.
# Note that the default vsftpd pam config also checks /etc/vsftpd/ftpusers
# for users that are denied.
#root
#bin
#daemon
#adm
#lp
#sync
#shutdown
#halt
#mail
#news
#uucp
#operator
#games
#nobody
EOF
 
for FTP_USER in $FTP_USERS; do
    PASSWORD=$(< /dev/urandom tr -dc '[:alnum:]' | head -c 8)
    cat >> $ACCOUNT_LIST << EOF
$FTP_USER
$PASSWORD
EOF
 
    echo "$FTP_USER" >> /etc/vsftpd/user_list
 
done
 
db_load -T -t hash -f $ACCOUNT_LIST /etc/vsftpd/virtual-users.db
chmod 600 $ACCOUNT_LIST
touch /etc/vsftpd/chroot_list
cat > /etc/pam.d/vsftpd-virtual <<EOF
auth required pam_userdb.so db=/etc/vsftpd/virtual-users
account required pam_userdb.so db=/etc/vsftpd/virtual-users
EOF
 
echo "-----------------------------------------------------------------------------"
/etc/init.d/vsftpd start
echo "-----------------------------------------------------------------------------"
echo "[Info]: Done. You can find your ftp password in $ACCOUNT_LIST"
echo "-----------------------------------------------------------------------------"

exit 0


#/etc/vsftpd/user_conf
#local_root=/var/www/sites/www.nginx.com/
#write_enable=YES
#virtual_use_local_privs=YES
#local_umask=002
#chown_uploads=YES
#chown_username=nginx

