<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright 2022 Joyent, Inc.
    Copyright 2022 MNX Cloud, Inc.
-->

# Triton "Grab Bag" of Miscelaneous Tools

This directory contains miscellaneous tools that are not shipped with Triton,
but users may find useful in some circumstances. Some of these tools may be
included as part of Triton in the future.

## Some things to know

Generally these would be copied to `/opt/custom/bin`. Most (but not all) will
only work on the headnode.

These tools are **not supported** by commercial contracts. Help for these tools
are from the community only (i.e., mailing lists, IRC).

These tools may have little to no error handling and may break things in
strange and wonderous ways. Understand what you're running before you use it.

## Included Tools

Here's a brief description of each tool. See the help (usually `-h`) or source
of each for additional info.

<!--
    Try to keep this list in alphabetical order, and the table under 80 columns
  -->

| Command                | Description                                         |
| ---------------------- | --------------------------------------------------- |
| amonalarms-clear       | Clear all amon alarms for specified user            |
| cn-comments            | Edit comments field in cnapi                        |
| cn-hostname            | Change the hostname of a CN                         |
| cn-trait               | Edit CN traits                                      |
| docker2uuid            | Look up UUID of a zone based on the short Docker ID |
| fp-search              | Search UFDS for accounts that have key fingerprint  |
| get_link_lldp.sh       | Report LLDP links                                   |
| getldp.pl              | Dump raw LDP output                                 |
| make-operator          | Add user to operator group in UFDS                  |
| pipasswd               | Look up default platform password                   |
| sdc-ip-capacity        | Show capacity utilization of a network in NAPI      |
| sdc-wasted-ips         | Show IPs marked used, but not actually in use       |
| triton-operator-report | List all Triton operators                           |
| triton-user-keytrace   | Find keys of specified user in other accounts       |
| update-all             | Blindly upgrade all components. Use with caution.   |
| update-pi              | Install latest PI & assign to all CNs for next boot |
