#!/bin/sh
DEBUG_LEVEL=${DEBUG_LEVEL:=0}
# "suggest" install standard setup
USERS_LDIF_FILE=${USERS_LDIF_FILE:="suggest"}
PATH=$PATH:/cnt/bin


function show_help
{
  echo "tbd."
}

function parse_cmdline
{
  while [[ $# > 0 ]]
  do 
    ARG="$1"
  
    case $ARG in
      -h|--help)
      show_help
      exit 0
      ;;

      --admin-name)
      ADMIN_NAME=$2
      shift
      ;;
  
      --admin-name=*)
      ADMIN_NAME=${ARG#*=}
      ;;
   
 
      --admin-password)
      ADMIN_PASSWORD=$2
      shift
      ;;
  
      --admin-password=*)
      ADMIN_PASSWORD=${ARG#*=}
      ;;
   
      --password)
      PASSWORD=$2
      shift
      ;;
  
      --password=*)
      PASSWORD=${ARG#*=}
      ;;
  
      --fqdn)
      FQDN=$2
      shift
      ;;
  
      --fqdn=*)
      FQDN=${ARG#*=}
      ;;

      --users-ldif-file)
      USERS_LDIF_FILE=$2
      shift
      ;;

      --users-ldif-file=*)
      USERS_LDIF_FILE=${ARG#*=}
      ;;

      --debug-level)
      DEBUG_LEVEL=$2
      shift
      ;;

      --debug-level=*)
      DEBUG_LEVEL=${ARG#*=}
      ;;


      --server-id)
      SERVER_ID=$2
      shift
      ;;

      --server-id=*)
      SERVER_ID=${ARG#*=}
      ;;

      --suffix)
      SUFFIX=$2
      shift
      ;;

      --suffix=*)
      SUFFIX=${ARG#*=}
      ;;


     esac
    shift 
  done 
}

function dump_setup_inf
{
cat <<EOF
[General]
FullMachineName=$FQDN
SuiteSpotUserID=nobody
SuiteSpotGroup=nobody
AdminDomain=$DOMAIN
ConfigDirectoryAdminID=$CADMIN_ID
ConfigDirectoryAdminPwd=$CADMIN_PW
ConfigDirectoryLdapURL=ldap://$FQDN:389/o=NetscapeRoot

[slapd]
SlapdConfigForMC=Yes
UseExistingMC=No
ServerPort=389
ServerIdentifier=$SERVER_ID
Suffix=$SUFFIX
RootDN=cn=Directory Manager
RootDNPwd=$DM_PASS
InstallLdifFile=$USERS_LDIF_FILE
#ConfigFile=$CONFIG_FILE

[admin]
Port=9830
ServerIpAddress=0.0.0.0
ServerAdminID=$SADMIN_ID
ServerAdminPwd=$SADMIN_PW
EOF
}

function wait_for_log_entry
{
  local LOG_FILE=$1
  local ENTRY=$2

  # Wait for completion of update
  while true; do
    grep -m 1 "$ENTRY" "$LOG_FILE" >/dev/null
    RET=$?
    if [ $RET == 0 ]; then 
      break
    fi 
    sleep 0.3
  done  
}



parse_cmdline "$@"

if [ -z "$FQDN" ]; then
  echo "fqdn is not set"
  exit 1
fi 

if [[ "$FQDN" != *"."*  ]]; then
  echo "fqdn string is not a fully qualified domain name"
  exit 2
fi 

DOMAIN=${DOMAIN:=${FQDN#*.}}
if [ -z "$DOMAIN" ]; then
  echo "fqdn does not contain a domain"
  exit 2
fi

# if SERVER_ID was not set, take the first part of the fqdn
if [ -z "$SERVER_ID" ]; then
  SERVER_ID=${SERVER_ID:=${FQDN%%.*}}
fi 

# if SUFFIX was not set, take the domain of the fqdn
if [ -z "$SUFFIX" ]; then
  SUFFIX=${SUFFIX:="dc="${DOMAIN/\./,dc=}}
fi 

if [ $DEBUG_LEVEL != 0 ]; then
  echo "PASSWORD=$PASSWORD"
  echo "ADMIN_PASSWORD=$ADMIN_PASSWORD"
  echo "FQDN=$FQDN"
  echo "DOMAIN=$DOMAIN"
  echo "SERVER_ID=$SERVER_ID"
  echo "SUFFIX=$SUFFIX"
fi 

    ADMIN_NAME=${ADMIN_NAME:="admin"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:="ldap389"}
      PASSWORD=${PASSWORD:="ldap389"}

CADMIN_ID=$ADMIN_NAME
SADMIN_ID=$ADMIN_NAME
CADMIN_PW=$ADMIN_PASSWORD
SADMIN_PW=$ADMIN_PASSWORD
DM_PASS=$PASSWORD

if [ ! -d "/etc/dirsrv/slapd-$SERVER_ID" ]; then
  dump_setup_inf >/cnt/setup-ds.inf

  if [ $DEBUG_LEVEL != 0 ]; then
	DEBUGARG="--debug"
  fi 

  setup-ds.pl --silent $DEBUGARG --logfile /dev/stdout --file /cnt/setup-ds.inf

  # It makes no sense to log in the container - only for debugging, so make it optional
  DSE_LDIF_FILE=/etc/dirsrv/slapd-$SERVER_ID/dse.ldif

  # Turn off default - makes no sense in a container
  if [ "$ACCESS_LOG" != "on" ]; then 
    sed -i.orig0 's/^nsslapd-accesslog-logging-enabled: on/nsslapd-accesslog-logging-enabled: off/' $DSE_LDIF_FILE 
  fi 

  # Turn off default - makes no sense in a container

  if [ "$ERROR_LOG" != "on" ]; then 
    sed -i.orig1 's/^nsslapd-errorlog-logging-enabled: on/nsslapd-errorlog-logging-enabled: off/'   $DSE_LDIF_FILE
  fi

  bash -x certs.sh $SERVER_ID
  CERT_SUCCESS=$?

  turn-on-memberof-plugin.sh $DSE_LDIF_FILE
  LOG_FILE=/tmp/log

  touch $LOG_FILE
  chmod 777 $LOG_FILE
  tail -f $LOG_FILE >/dev/stdout &
  /usr/sbin/ns-slapd -D "/etc/dirsrv/slapd-$SERVER_ID" -i "/var/run/dirsrv/slapd-$SERVER_ID.pid" -d 0 2>$LOG_FILE &
  
  wait_for_log_entry "$LOG_FILE" "slapd started."

  if [ $CERT_SUCCESS == 0 ]; then 
    CERT_NICK=$(certutil -d /etc/dirsrv/slapd-$SERVER_ID  -L |grep 'u,u,u$' |sed -r 's/[ ]+u,u,u$//')
    # SSL Encryption
    sed -i""  "s/^nsSSLPersonalitySSL:.*$/nsSSLPersonalitySSL: $CERT_NICK/"  /cnt/ldif/turn-on-ssl-encryption.ldif
    ldapmodify -x -h localhost -p 389 -D "cn=Directory Manager" -w $CADMIN_PW </cnt/ldif/turn-on-ssl-encryption.ldif
    # End SSL Encryption
  fi 

  # Update Membership
  sed -i.orig "s/basedn:.*$/basedn: $SUFFIX/" /cnt/ldif/fix-member-of-task.ldif
  ldapadd -h localhost -p 389 -D "cn=Directory Manager" -w $CADMIN_PW -f /cnt/ldif/fix-member-of-task.ldif

  wait_for_log_entry "$LOG_FILE" "memberof-plugin - Memberof task finished"

  PID=$(cat "/var/run/dirsrv/slapd-$SERVER_ID.pid")
  kill -TERM $PID
  wait $PID


  rm -f "$LOG_FILE"
  # kill remaining childs (should be tail -f )
  kill -TERM $(jobs -p) 

else 
  # Refresh always
  certs.sh $SERVER_ID
fi


VAR_LOCK_DIR="/var/lock/dirsrv/slapd-$SERVER_ID"

if [ -d "$VAR_LOCK_DIR" ]; then
 rm -rf "$VAR_LOCK_DIR"
fi
mkdir -p            "$VAR_LOCK_DIR"
chmod 0755          "$VAR_LOCK_DIR"
chown nobody.nobody "$VAR_LOCK_DIR"

exec /usr/sbin/ns-slapd -D "/etc/dirsrv/slapd-$SERVER_ID" -i "/var/run/dirsrv/slapd-$SERVER_ID.pid" -d 0 >/dev/null
