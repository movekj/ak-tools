#!/bin/bash
# Description:
#     * generate self-signed SSL certificate easily

CURRENT_DIR="$(pwd)"
OPENSSL_BIN="/usr/bin/openssl"
EXPIRED_DAY=3650
 
check_last_cmd(){
    if [ $? -ne 0 ];then
        echo -e "\\033[1;31mFAILED\\033[0m"
        exit 1
    fi
}

if [ ! -x "$OPENSSL_BIN" ]; then
    echo "Invalid openssl command, using: $OPENSSL_BIN"
    exit 1
fi

# remove old certificate
if [ $(ls -1 $CURRENT_DIR/*{.csr,.crt,.key,.orig} 2>/dev/null | wc -l) -gt 0 ]; then
    echo "[INFO]: Old SSL crt/key/csr found ..."
    echo "--------------------------------------------------------------------------------"
    /bin/ls -1 $CURRENT_DIR/*{.csr,.crt,.key,.orig} 2>/dev/null
    echo "--------------------------------------------------------------------------------"

    read -p  "[WARNING]: Do you want to delete the files?(yes/no) " ANSWER
    if [ "$ANSWER" != "yes" ]; then
        echo "[INFO]: Cancelled."
        exit 1
    else
        /bin/rm -fv $CURRENT_DIR/*{.csr,.crt,.key,.orig} 
    fi 
fi
 
echo "-----------------------------------------------------------------"
read -p "Please input your domain name: " DOMAIN_NAME
 
echo "-----------------------------------------------------------------"
echo "[INFO]: Generating OpenSSL RSA Parameters ..."
$OPENSSL_BIN genrsa -des3 -out $DOMAIN_NAME.key 2048
check_last_cmd
 
echo "-----------------------------------------------------------------"
echo "[INFO]: Generating Certificate Signing Request ..."
$OPENSSL_BIN req -new -key $DOMAIN_NAME.key -out $DOMAIN_NAME.csr
check_last_cmd

/bin/cp $DOMAIN_NAME.key $DOMAIN_NAME.key.orig
echo "-----------------------------------------------------------------"
echo "[INFO]: Removing Passphrase ..."
$OPENSSL_BIN rsa -in $DOMAIN_NAME.key.orig -out $DOMAIN_NAME.key 2>/dev/null
check_last_cmd
 
echo "-----------------------------------------------------------------"
echo "[INFO]: Generating Self-Signed Certificate"
$OPENSSL_BIN x509 -req -days $EXPIRED_DAY -in $DOMAIN_NAME.csr -signkey $DOMAIN_NAME.key -out $DOMAIN_NAME.crt
check_last_cmd
 
# validate key
echo "-----------------------------------------------------------------"
echo "[INFO]: Validating key: $DOMAIN_NAME.key" 
$OPENSSL_BIN rsa -in $DOMAIN_NAME.key -check
check_last_cmd

echo "-----------------------------------------------------------------"
echo "[INFO]: Validating csr: $DOMAIN_NAME.csr" 
# validate Certificate Signing Request (CSR)
$OPENSSL_BIN req -text -noout -verify -in $DOMAIN_NAME.csr 
check_last_cmd

# validate certificate
echo "-----------------------------------------------------------------"
echo "[INFO]: Validating crt: $DOMAIN_NAME.crt" 
$OPENSSL_BIN x509 -text -noout -in $DOMAIN_NAME.crt
check_last_cmd

/bin/rm $(pwd)/$DOMAIN_NAME.csr
/bin/rm $(pwd)/$DOMAIN_NAME.key.orig
echo "-----------------------------------------------------------------"
echo "[INFO]: Private Key: $(pwd)/$DOMAIN_NAME.key"
echo "[INFO]: Certificate: $(pwd)/$DOMAIN_NAME.crt"
echo "-----------------------------------------------------------------"
cat << EOF
    # nginx sample 
    listen              443 ssl;
    server_name         $DOMAIN_NAME;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA'; 
    ssl_prefer_server_ciphers on;
    ssl_certificate     $(pwd)/$DOMAIN_NAME.crt;  
    ssl_certificate_key $(pwd)/$DOMAIN_NAME.key; 
    ssl_session_timeout 1d;
    ssl_session_cache   shared:SSL:10m;
    # add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains';
EOF
