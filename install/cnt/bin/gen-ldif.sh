#!/bin/sh
#SUFFIX="dc=example,dc=com"
#FILENAME="table"

DIRNAME=$(dirname $0)
if [ ! -f "$DIRNAME/gen.conf" ]; then
   echo "gen.conf missing."
   exit 1
fi

. "$DIRNAME/gen.conf"

function print_header()
{
local SUFFIX=$1
local PREFIX=$(awk -F, '{print $1;}' <<<$SUFFIX|awk -F= '{print $2}' )
#echo $PREFIX

cat <<EOF
version: 1

# entry-id: 1
dn: $SUFFIX
objectClass: top
objectClass: domain
dc: $PREFIX
aci: (targetattr!="userPassword || aci")(version 3.0; acl "Enable anonymous access"; allow (read, search, compare) userdn="ldap:///anyone";)
aci: (targetattr="carLicense || description || displayName || facsimileTelephoneNumber || homePhone || homePostalAddress || initials || jpegPhoto || labeledURI || mail || mobile || pager || photo || postOfficeBox || postalAddress || postalCode || preferredDeliveryMethod || preferredLanguage || registeredAddress || roomNumber || secretary || seeAlso || st || street || telephoneNumber || telexNumber || title || userCertificate || userPassword || userSMIMECertificate || x500UniqueIdentifier")(version 3.0; acl "Enable self write for common attributes"; allow (write) userdn="ldap:///self";)
aci: (targetattr ="*")(version 3.0;acl "Directory Administrators Group";allow (all) (groupdn = "ldap:///cn=Directory Administrators, $SUFFIX");)

# entry-id: 2
dn: cn=Directory Administrators,$SUFFIX
objectClass: top
objectClass: groupofuniquenames
cn: Directory Administrators
uniqueMember: cn=Directory Manager

# entry-id: 3
dn: ou=Groups,$SUFFIX
objectClass: top
objectClass: organizationalunit
ou: Groups

# entry-id: 4
dn: ou=People,$SUFFIX
objectClass: top
objectClass: organizationalunit
ou: People
aci: (targetattr ="userpassword || telephonenumber || facsimiletelephonenumber")(version 3.0;acl "Allow self entry modification";allow (write)(userdn = "ldap:///self");)
aci: (targetattr !="cn || sn || uid")(targetfilter ="(ou=Accounting)")(version 3.0;acl "Accounting Managers Group Permissions";allow (write)(groupdn = "ldap:///cn=Accounting Managers,ou=groups,$SUFFIX");)
aci: (targetattr !="cn || sn || uid")(targetfilter ="(ou=Human Resources)")(version 3.0;acl "HR Group Permissions";allow (write)(groupdn = "ldap:///cn=HR Managers,ou=groups,$SUFFIX");)
aci: (targetattr !="cn ||sn || uid")(targetfilter ="(ou=Product Testing)")(version 3.0;acl "QA Group Permissions";allow (write)(groupdn = "ldap:///cn=QA Managers,ou=groups,$SUFFIX");)
aci: (targetattr !="cn || sn || uid")(targetfilter ="(ou=Product Development)")(version 3.0;acl "Engineering Group Permissions";allow (write)(groupdn = "ldap:///cn=PD Managers,ou=groups,$SUFFIX");)

# entry-id: 5
dn: ou=Special Users,$SUFFIX
objectClass: top
objectClass: organizationalUnit
ou: Special Users
description: Special Administrative Accounts

# entry-id: 6
dn: cn=Accounting Managers,ou=Groups,$SUFFIX
objectClass: top
objectClass: groupOfUniqueNames
cn: Accounting Managers
ou: groups
description: People who can manage accounting entries
uniqueMember: cn=Directory Manager

# entry-id: 7
dn: cn=HR Managers,ou=Groups,$SUFFIX
objectClass: top
objectClass: groupOfUniqueNames
cn: HR Managers
ou: groups
description: People who can manage HR entries
uniqueMember: cn=Directory Manager

# entry-id: 8
dn: cn=QA Managers,ou=Groups,$SUFFIX
objectClass: top
objectClass: groupOfUniqueNames
cn: QA Managers
ou: groups
description: People who can manage QA entries
uniqueMember: cn=Directory Manager

# entry-id: 9
dn: cn=PD Managers,ou=Groups,$SUFFIX
objectClass: top
objectClass: groupOfUniqueNames
cn: PD Managers
ou: groups
description: People who can manage engineer entries
uniqueMember: cn=Directory Manager

EOF
}


function print_user
{

cat <<EOF
dn: uid=$_UID,ou=People,$SUFFIX
givenName: $GIVEN_NAME
sn: $SURNAME
loginShell: $LOGINSHELL
gidNumber: $_GID_NUMBER
uidNumber: $_UID_NUMBER
mail: $EMAIL
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetorgperson
objectClass: inetUser
objectClass: posixAccount
uid: $_UID
gecos: $GIVEN_NAME $SURNAME
cn: $GIVEN_NAME $SURNAME
homeDirectory: $HOME
passwordGraceUserTime: 0
EOF
if [ ! -z "$PHONE" ]; then
  echo "telephoneNumber: $PHONE"
fi 
if [ ! -z "$PASSWORD" ]; then
  echo "userPassword: {$SCHEME}$PASSWORD"
fi 
echo ""
}
function print_group 
{
LINE=$1
#echo "*** $LINE"

RFC="RFC2037bis"

if [ "$RFC" == "RFC2037" ]; then
# RFC2037
GROUP_ENTRY="groupOfUniqueNames"
else 
# RFC2037bis (Draft 02)
#GROUP_ENTRY="groupOfMembers"  # This seems not to work with slapd of ldap 389
GROUP_ENTRY="groupOfNames"
fi

cat <<EOF
dn: cn=$_GID,ou=Groups,$SUFFIX
gidNumber: $_GID_NUMBER
objectClass: top
objectClass: $GROUP_ENTRY
objectClass: posixgroup
cn: $_GID
EOF
awk -F: '{ groups=$4;split(groups,a, ","); for (i=1; i <= length(a);i++) { print "memberuid: "a[i]};}' <<<$LINE
if [ "$RFC" == "RFC2037" ]; then
  awk -F: -vsuffix=$SUFFIX '{ groups=$4;split(groups,a, ","); for (i=1; i <= length(a);i++) { print "uniqueMember: uid="a[i]",ou=People,"suffix}}' <<<$LINE
else 
  awk -F: -vsuffix=$SUFFIX '{ groups=$4;split(groups,a, ","); for (i=1; i <= length(a);i++) { print "member: uid="a[i]",ou=People,"suffix}}' <<<$LINE

fi
#awk -F: -vsuffix=$SUFFIX '{ groups=$4;split(groups,a, ","); for (i=1; i <= length(a);i++) { print "uniqueMember: uid="a[i]}}' <<<$LINE
#awk -F: -vsuffix=$SUFFIX '{ groups=$4;split(groups,a, ","); for (i=1; i <= length(a);i++) { print "member: uid="a[i]",ou=People,"suffix}}' <<<$LINE
echo ""
}

function process_line()
{
  local LINE=$1
  local SUFFIX=$2
  eval $(awk -F: '{print "TYPE="$1}' <<<$LINE)
  if [ "$TYPE" == "u" ];  then
     eval $(awk -F: '{print "TYPE="$1"\n_UID="$2"\n_UID_NUMBER="$3"\n_GID_NUMBER="$4"\nHOME="$5"\nLOGINSHELL="$6"\nGIVEN_NAME="$7"\nSURNAME="$8"\nEMAIL="$9"\nPHONE="$10"\nSCHEME="$11"\nPASSWORD="$12"\n";}'  <<<$LINE)
     print_user
  fi 
  if [ "$TYPE" == "g" ];  then
   eval $(awk -F: '{print "TYPE="$1"\n_GID="$2"\n_GID_NUMBER="$3"\n"}' <<<$LINE)
   print_group "$LINE"
  fi 
}

print_header "$SUFFIX"
cat "$FILENAME"|while read -r LINE ; do
  process_line $LINE $SUFFIX
done 
