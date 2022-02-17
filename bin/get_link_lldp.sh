#!/usr/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2022 Joyent, Inc.

# shellcheck disable=SC2154
if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi

dirname="${0%/*}"
# Requires perl installed from pkgsrc-tools
GETLDP="${dirname}/getldp.pl"

tout=60

while [[ $# -gt 0 ]];
do
  opt="${1}"
  shift
  case "$opt" in
    "-t" ) tout=${1:-$tout};shift;;
    *)
      echo "Error: Unknown option '-${opt}'" >&2
  esac
done

#########################################################################################
## Find lldp information from each interface
#########################################################################################

dladm="/usr/sbin/dladm"
svcs="/usr/bin/svcs"
svcadm="/usr/sbin/svcadm"
echo="/usr/bin/echo"
# awk="/usr/bin/awk"
serial=$(pfexec /usr/bin/sysinfo | /usr/bin/json "Serial Number")
# hostname=$(/usr/bin/hostname)

# disable lldp/server, so we can snoop the interface
# without interference from on-board lldp/server

foundenabled=0
if [ "$( ${svcs} -Ho STATE lldp/server )" == "online" ];then
   ${svcadm} disable lldp/server
   foundenabled=1
fi

for nic in $(${dladm} show-phys -p -o state,link | awk -F: '/^up/ {print $2}' | sort); do
    MAC=$(${dladm} show-phys -m -o address -p "${nic}")
    PORTSWITCH=$(pfexec "${GETLDP}" -l -x -t "${tout}" -i "${nic}" 2>/dev/null | awk '/^  port-id:/{ ret=0;for (i=2;i<=NF;++i) { if(ret==1) { printf " "};printf $i;ret=1 };printf "," } /^  sysName:/{ printf("%s\n",$2) }')
    #${echo} "${hostname},${nic},${MAC},${PORTSWITCH}"
    ${echo} "${serial},${nic},${MAC},${PORTSWITCH}"
done

if [ ${foundenabled} -eq 1 ];then
   ${svcadm} enable lldp/server
fi
