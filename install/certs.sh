#!/bin/sh
SERVER_ID=$1
CA_CERT_DESC="Server-Cert"
CERT_DESC="Server-Cert"
DEST_FILE="/tmp/key.p12"

SSL_CHECK=0
for i in CA_CERT_FILE CERT_FILE KEY_FILE; do 
  eval "FILE=\$$i"
  if [ ! -f  "$FILE" ]; then
     echo "'$FILE' in $i does not exist"
     SSL_CHECK=1
  fi
done

if [ $SSL_CHECK !=  0 ]; then 
  exit 1
fi 

certutil\
    -d "/etc/dirsrv/slapd-$SERVER_ID"\
    -A\
    -t "CT,,"\
    -n "$CA_CERT_DESC"\
    -i "$CA_CERT_FILE"

certutil\
	-d "/etc/dirsrv/slapd-$SERVER_ID"\
	-L

echo "tmp" >/tmp/foo

openssl pkcs12 -export\
    -name   "$CERT_DESC"\
    -in     "$CERT_FILE"\
    -inkey  "$KEY_FILE"\
    -out    "$DEST_FILE"\
    -passout pass:tmp

# INSERT or UPDATE - it always overwrites here

pk12util\
  -i "$DEST_FILE"\
  -d /etc/dirsrv/slapd-${SERVER_ID}/\
  -w /tmp/foo\
  -K ""

