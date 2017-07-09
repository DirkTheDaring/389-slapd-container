#!/bin/sh
DSE_LDIF=$1
DSE_LDIF=${DSE_LDIF:="dse.ldif"}

function get_member_of_section_line_numbers
{
  local FILENAME=$1
  awk '/^dn: cn=MemberOf Plugin,cn=plugins,cn=config/ { a=1; printf NR} /^$/ { if (a ==1 ) {a=0;print","NR}}' "$FILENAME"
}
# find start and end line of section
LINE_NUMBERS=$(get_member_of_section_line_numbers "$DSE_LDIF")
# Patch accordingly
sed -i.orig10  "${LINE_NUMBERS}s/^nsslapd-pluginenabled:.*$/nsslapd-pluginEnabled: on/g" "$DSE_LDIF"

RFC="RFC2037BIS"
if [ "$RFC" == "RFC2037" ]; then
  sed -i.orig11  "${LINE_NUMBERS}s/^memberofgroupattr:.*$/memberofgroupattr: uniqueMember/g" "$DSE_LDIF"
fi 
sed -i.orig12  "${LINE_NUMBERS}s/^memberofattr:.*$/memberofattr: memberOf/g" "$DSE_LDIF"

