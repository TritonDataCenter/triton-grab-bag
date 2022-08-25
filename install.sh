#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2022 MNX Cloud, Inc.
#

# shellcheck disable=SC2154
if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail

source=https://github.com/TritonDataCenter/triton-grab-bag/archive/refs/heads/master.tar.gz
rootcerts=/opt/tools/share/mozilla-rootcerts/cacert.pem

fatal() {
    printf '%s' "$*"
    exit 1
}

_wdir=$(mktemp -d)

cd "$_wdir" || fatal "Could not cd to $_wdir"
if [[ -f $rootcerts ]]; then
    export CURL_CA_BUNDLE="$rootcerts"
else
    printf 'Warning: No root certs available. Bypassing certificate validation.\n' >&2
    printf 'This may be unsafe.\n' >&2
    alias curl='curl --insecure'
fi
export CURL_CA_BUNDLE

printf 'Downloading grab bag...\n'
curl -# -LOC - "$source"
printf 'Extracting file...'
gtar zxf "$(basename "$source")"
printf 'done.\n'
printf 'Installing...'
rsync -a --delete triton-grab-bag-master/ /opt/gb/
printf 'done.\n'

cd / || fatal 'Could not cd to /'

rm -rf "${_wdir:?}"
