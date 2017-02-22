#!/bin/bash

LDAP_SERVER="ldaps://localhost/"
DN="dc=domain,dc=com"
LOGIN_DN="cn=Manager,$DN"
USER_OU="ou=users,$DN"
GROUP_OU="ou=groups,$DN"

# LDAP Manager passwd
DEFAULT_PASS="myLDAP01"

# the default ldap gid. 2000 for ldap_user
DEFAULT_GID="2000"

show_help() {
    echo "Usage: $0 <sub-command>
sub-command:
    add                 Add a new LDAP user
    chgroup             Change LDAP user group
    chshell             Change user login shell 
    delete              Delete a LDAP user
    reset               Reset user password
    show                Show information about groups and users
"
}

echo_error() {
    echo -e "\\033[1;31m[ERROR]: $1\\033[0m"
}

echo_info() {
    echo -e "\\033[0;32m[INFO]: $1\\033[0m"
}

echo_warn() {
    echo -e "\\033[1;33m[WARNING]: $1\\033[0m"
}


rootdn_check() {
    if [ -z "$DEFAULT_PASS" ]; then
        read -s -p "Please input LDAP management password: " LDAP_PASS
        echo
    else
        LDAP_PASS=$DEFAULT_PASS
    fi

    # password check
    ldapsearch -x -LLL -D "$LOGIN_DN" -w $LDAP_PASS >/dev/null
    if [ $? -ne 0 ]; then
        echo_error "LDAP bind failed, invalid DN or password." 
        exit 1
    else
        echo_info "Password verified."
    fi
}


ldap_reset() {
    rootdn_check
    echo_info "Start to reset user password ... "
    if [ "$1" == "" ]; then
        read -p  "Please input the username:" LDAP_UID
    else
        LDAP_UID="$1"
    fi

    USER_INFO=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $USER_OU "cn=$LDAP_UID" | grep -v userPassword)
    if [ -z "$USER_INFO" ]; then
        echo_error "Invalid user, $LDAP_UID does NOT exist." 
        exit 1
    fi

    read -p "[INFO]: Do you want to input a new password by yourself? (yes/NO) " ANSWER
    
    if [ "$ANSWER" == "yes" ]; then
        echo_info "Your password should be 8+ charchters, including uppercase letter and lower case letter and numbers"
        while [ "$PASS_READY" != "yes" ]; do
            read -s -p "New password: "  PW1
            echo
            PW1_CHECK=$(echo $PW1 | egrep "^.{8,255}" | egrep "[A-Z]" | egrep "[a-z"] | egrep "[0-9]") 
            if [ -z "$PW1_CHECK" ]; then
                echo_warn "Password complexity check failed (8+ charchters, mixed with lower and upper case and numbers)" 
                continue
            fi
            read -s -p "Retype new password: " PW2
            echo
            if [ "$PW1" != "$PW2" ]; then
                echo "Sorry, passwords do not match."
                continue
            else
                USER_SECRET="$PW1"
                PASS_READY="yes"
            fi
        done
    else
        echo "[INFO]: System generated a new password for you automatically."
        USER_SECRET="$(< /dev/urandom tr -dc '[:alnum:]' | head -c 10)"
    fi

    USER_PASS="$(slappasswd -s $USER_SECRET 2>/dev/null)"
    ldappasswd -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -s $USER_SECRET  "cn=$LDAP_UID,$USER_OU"

    if [ $? -eq 0 ]; then
        if [ "$PASS_READY" == "yes" ]; then
            echo "[INFO]: Password changed successfully." 
        else
            echo "[INFO]: Password changed successfully." 
            echo "[INFO]: Your new password: $USER_SECRET"
        fi
    else
        echo_error "Failed to reset passsword for $LDAP_UID"
        exit 1
    fi
}


ldap_delete() {
    rootdn_check
    if [ "$1" == "" ]; then
        echo_warn "This will delete all user/group information realated to the user. "
        read -p  "Please input the user to be deleted: " LDAP_UID
    else
        LDAP_UID="$1"
    fi

    USER_INFO=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $USER_OU "cn=$LDAP_UID" | grep -v userPassword)
    if [ -z "$USER_INFO" ]; then
        echo_error "Invalid user, $LDAP_UID does NOT exist."
        exit 1
    fi

    echo "--------------------------------------------------------------------------"
    echo "$USER_INFO"
    echo "--------------------------------------------------------------------------"
    read -p "[INFO]: Going to delete ldap user $LDAP_UID. Do you want to continue?(yes/NO) " ANSWER
    if [ $ANSWER == "yes" ]; then
        echo_info "Cleaning user information ..."
        ldapdelete -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" "cn=$LDAP_UID,$USER_OU"
        if [ $? -eq 0 ]; then
            echo_info "Done."
        else
            echo_error "Failed to delete $LDAP_UID" 
        fi

        echo_info "Cleaning group information ..."
        for i in $(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $GROUP_OU | awk '/cn:/ {print $2}'); do
            echo "dn: cn=$i,$GROUP_OU
changetype: modify
delete: memberUid
memberUid: $LDAP_UID
" | ldapmodify -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" &>/dev/null
        done
        echo_info "Done."
        
    else
        echo "Cancelled."
        exit 1
    fi
}

ldap_add() {
    rootdn_check
    echo_info "Start to create a new LDAP user ... "
    USER_SECRET="$(< /dev/urandom tr -dc '[:alnum:]' | head -c 10)"
    USER_PASS="$(slappasswd -s $USER_SECRET 2>/dev/null)"
    if [ -z "$USER_PASS" ]; then
        echo_error "Failed to generate SSHA password." 
        exit 1
    fi
    
    while [ "$CONFIRMED" != "yes" ]; do
        read -p "input User ID: " LDAP_UID 
        if [ -z "$LDAP_UID" ]; then
            echo_warn "User ID can NOT be empty, please try again."
            echo "--------------------------------------------------------------------------"
            continue
        fi

        USER_INFO=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $USER_OU "cn=$LDAP_UID" | grep -v userPassword)
        if [ -n "$USER_INFO" ]; then
            echo "--------------------------------------------------------------------------"
            echo "$USER_INFO"
            echo "--------------------------------------------------------------------------"
            echo_warn "User $LDAP_UID already exists, please try again."
            echo "--------------------------------------------------------------------------"
            continue
        fi

        read -p "input User GivenName: " GNAME
        read -p "input User FamilyName: " FNAME
    
        if [ -z "$GNAME" -o -z "$FNAME" ]; then
            echo_warn "GivenName/FamilyName can NOT be empty, please try again."
            echo "--------------------------------------------------------------------------"
            continue
        fi
    
        read -p "Do you want $LDAP_UID have /bin/bash privileges? (yes/NO) " ANSWER
        if [ "$ANSWER" == "yes" ]; then
            LOGIN_SHELL="/bin/bash"
            echo_info "Shell login privelege granted."
        else
            LOGIN_SHELL="/sbin/nologin"
            echo_warn "Shell login is disabled"
        fi
        
        UID_NUM=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $USER_OU | awk -F: 'BEGIN {max = 0} /uidNumber/ {if ($2>max) max=$2} END {print max+1}')
        if [ -z "$UID_NUM" ]; then
            echo_error "Failed to generate ldap uid number."
            exit 1
        fi 
    
        TMP_FILE=$(mktemp)
        cat > $TMP_FILE << EOF 
dn: cn=$LDAP_UID,$USER_OU
objectClass: posixAccount
objectClass: inetOrgPerson
cn: $LDAP_UID
givenName: $GNAME
sn: $FNAME
uid: $LDAP_UID
homeDirectory: /home/ldaps/$LDAP_UID
gecos: $GNAME $FNAME
loginShell: $LOGIN_SHELL
gidNumber: $DEFAULT_GID
uidNumber: $UID_NUM
userPassword: $USER_PASS
EOF
        CONFIRMED="yes"
    done

    ldapadd -a -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -f $TMP_FILE >/dev/null 
    if [ $? -ne 0 ]; then
        echo "--------------------------------------------------------------------------"
        cat -te $TMP_FILE
        echo "--------------------------------------------------------------------------"
        echo_error "Failed to add new entry."
        /bin/rm -f $TMP_FILE
        exit 1
    else
        echo "--------------------------------------------------------------------------"
        cat $TMP_FILE
        echo "--------------------------------------------------------------------------"
        echo_info "LDAP user $LDAP_UID added successfully."
        echo_info "user name: $LDAP_UID"
        echo_info "user passwd: $USER_SECRET"
        /bin/rm -f $TMP_FILE
        exit 0
    fi
    echo_info "Cleaning cache, please wait ..."
    sss_cache -UG
    sleep 5
    id -a $LDAP_UID
}

ldap_chshell() {
    rootdn_check
    if [ "$1" == "" ]; then
        read -p  "Please input the username: " LDAP_UID
    else
        LDAP_UID="$1"
    fi
    
    USER_INFO=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $USER_OU "cn=$LDAP_UID")
    if [ -z "$USER_INFO" ]; then
        echo_error "Invalid user, user $LDAP_UID does NOT exist"
        exit 1 
    fi

    read -p "please input new login shell: " LOGIN_SHELL
    if [ -z "$LOGIN_SHELL" ]; then
        echo_error "login shell can NOT be empty"
        exit 1
    fi
    echo "dn: cn=$LDAP_UID,$USER_OU
changetype: modify
replace: loginShell
loginShell: $LOGIN_SHELL
" | ldapmodify -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" >/dev/null 
    if [ $? -ne 0 ]; then
        echo_error "Failed to update login shell"
        exit 1
    else
        echo_info "Done."
    fi 
}


ldap_chgroup() {
    rootdn_check
    if [ "$1" == "" ]; then
        read -p  "Please input the username:" LDAP_UID
    else
        LDAP_UID="$1"
    fi

    USER_INFO=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $USER_OU "cn=$LDAP_UID")
    if [ -z "$USER_INFO" ]; then
        echo_error "Invalid user, user $LDAP_UID does NOT exist"
        exit 1 
    fi
    echo "-------------------------------"
    echo_info "Current user information:"
    echo "-------------------------------"
    id -a $LDAP_UID
    echo "-------------------------------"
    echo_info "Current available groups:"
    echo "-------------------------------"
    ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $GROUP_OU | awk '/cn:/ {print $2}'
    echo "-------------------------------"
    read -p "input the new primary group: " PRIMARY_GROUP
    if [ -z "$PRIMARY_GROUP" ]; then
        echo_error "primary group can't be empry"
        exit 1
    fi

    read -p "input the new secondary groups(seperate with SPACE, group1 group2 group3): " SECONDARY_GROUP
    for i in $PRIMARY_GROUP $SECONDARY_GROUP; do
        GROUP_INFO=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $GROUP_OU "cn=$i")
        if [ -z "$GROUP_INFO" ]; then
            echo_warn "invalid group $i" 
            INVALID_GROUP="yes"
        fi
    done

    if [ "$INVALID_GROUP" == "yes" ]; then
        echo_error "Invalid group(s) detected, please try again."
        exit 1
    fi
   
    echo_info "Changing primiary group ..."
    PRIMARY_ID=$(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $GROUP_OU "cn=$PRIMARY_GROUP" | awk '/gidNumber:/ {print $2}')
    echo "dn: cn=$LDAP_UID,$USER_OU
changetype: modify
replace: gidNumber
gidNumber: $PRIMARY_ID
" | ldapmodify -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" >/dev/null 

    echo_info "Changing secondary group ..."
    for i in $(ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b $GROUP_OU | awk '/cn:/ {print $2}'); do
        GROUP_IN=""

        # always remove primary 
        if [ "$i" == "$PRIMARY_GROUP" ]; then
            #echo_warn "make sure $PRIMARY_GROUP not exist"
            echo "dn: cn=$LDAP_UID,$USER_OU
changetype: modify
delete: memberUid
memberUid: $LDAP_UID
" | ldapmodify -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" &>/dev/null
            continue
        fi

        for j in $SECONDARY_GROUP; do
            if [ "$i" == "$j" -a -n "$j" ]; then
                GROUP_IN="yes"
                break
            fi 
        done

# http://www.centos.org/docs/5/html/CDS/ag/8.0/Creating_Directory_Entries-LDIF_Update_Statements.html
        if [ -z "$GROUP_IN" ]; then
            #echo_warn "make sure $i not exist!"
            echo "dn: cn=$i,$GROUP_OU
changetype: modify
delete: memberUid
memberUid: $LDAP_UID
" | ldapmodify -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" &>/dev/null
        else
            #echo_warn "make sure $i exist"
            echo "dn: cn=$i,$GROUP_OU
changetype: modify
add: memberUid
memberUid: $LDAP_UID
" | ldapmodify -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" &>/dev/null 
        fi 
    done

    echo_info "Cleaning cache, please wait ..."
    sss_cache -UG
    sleep 5
    id -a $LDAP_UID
}

ldap_show() {
    rootdn_check
    # http://wiki.pentaho.com/display/ServerDoc2x/LDAP+Search+Filter+Syntax
    echo "-----------------------------------------------------------------------------"
    echo_info "Group information: "
    ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b "$GROUP_OU" cn gidNumber memberUid | sed '/dn: ou/d;s/dn:.*/--------------/g'|grep -v "^$"

    echo "-----------------------------------------------------------------------------"
    echo_info "User information - Login Shell - bash"
    ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b "$USER_OU" "(loginShell=/bin/bash)" cn uidNumber gidNumber loginShell | sed '/dn: ou/d;s/^dn:.*/------------/g'|grep -v "^$"

    echo "-----------------------------------------------------------------------------"
    echo_info "User information - Login Shell - others"
    ldapsearch -LLL -x -H $LDAP_SERVER -D "$LOGIN_DN" -w "$LDAP_PASS" -b "$USER_OU" "(!(loginShell=/bin/bash))" cn uidNumber gidNumber loginShell | sed '/dn: ou/d;s/^dn:.*/------------/g'|grep -v "^$"
    echo
}

case $1 in
    reset) ldap_reset "$2" ;; 
    delete) ldap_delete "$2" ;; 
    add) ldap_add ;; 
    chgroup) ldap_chgroup "$2" ;; 
    chshell) ldap_chshell "$2" ;; 
    show) ldap_show ;;
    *) show_help; exit 1 ;;
esac

