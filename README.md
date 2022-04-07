# Misc Tools

This directory contains miscellaneous tools that are not shipped with Triton,
but users may find useful in some circumstances. Some of these tools may be
include in the future.

Some things to know:

Generally these would be copied to `/opt/custom/bin`. Most (but not all) will
only work on the headnode.

These tools are **not supported** by commercial contracts. Help for these tools
are from the community only (i.e., mailing lists, IRC).

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
