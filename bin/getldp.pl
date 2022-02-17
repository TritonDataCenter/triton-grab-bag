#!/opt/tools/bin/perl
#
# getldp.pl
#
# This script simply looks for LDP (Link Discovery Protocol) packets 
# (CDP, LLDP) to determine the device connected to, device type, and
# interface port.
#
# Run with '-h' for help.  Sample output:
#    somehost [0] /usr/local/bin/getldp.pl -i hme0 -x -t 120
#    Watching for CDP packet on hme0 for 120 seconds...
#    device-id:      my.switch
#    platform:       cisco Catalyst C3650
#    sw-version:     Cisco IOS Software, C3750 Software (C3750-IPSERVICES-M), Version 12.2(25)SEB4, RELEASE SOFTWARE (fc1)
#    port-id:        FastEthernet6/41
#    vtp-mgmt-dom:   Services
#    mgmt-address:   10.128.32.76
#    native-vlan:    11
#    Duplex:         Full
#    CDPversion:     2
#
# Still need to include LLDP handling for Solaris.
#
#                       -:: TD - 1280550076 ::-
#
# added LLDP handling and options -d, -b
#
#                       -:: TD - 1282792871 ::-
#
# - v0.1.5 - added handling for CDP packets with ether type 0x8100; thanks
#   to Gary Brett for submitting related packet captures to test against
# - if CDP and ether type 0x8100 (802.1q tagged), retrieve priority and
#   VLAN ID from 802.1q header; corrected some syntax for tcpdump
# - corrected LLDP type handling ('ethertype' vs. 'ether proto') for
#   appropriate use solaris and Linux / FreeBSD
#
#                       -:: TD - 1300377693 ::-
#
# - v0.1.6 - includes patch updates from Vincent Cojot for CDP packets to
#   detail device capabilities (capabilities), OS version (sw-version),and
#   device management address (mgmt-address);  thanks to Vincent for
#   requesting the additional functionality and providing a patch including
#   said updates
# - due to Vincent's patch mentioned above for CDP, I've added code to
#   detail device capabilities and device management address (possible type
#   values: IPv4, IPv6, hwaddr) for LLDP packets (assuming those details are
#   included in the packet)
# - added availability to run on OSes other than Solaris, Linux, or FreeBSD,
#   assuming -b is used to set to the path for either 'snoop' or 'tcpdump'
#
#                       -:: TD - 1323496105 ::-
#
# - v0.1.7 - added handling to clean up orphan processes should we timeout
#   waiting on data;  prior to this, one had to manually reap the orphans
#   out of the process table (tested on Solaris, Linux, and FreeBSD)
#
#                       -:: TD - 1325110097 ::-
#
# COPYRIGHT: Copyright (c) 2010-2011 Troy Dietrich.
#
# CDDL HEADER START
#
#  The contents of this file are subject to the terms of the
#  Common Development and Distribution License, Version 1.0 only
#  (the "License").  You may not use this file except in compliance
#  with the License.
#
#  You can obtain a copy of the license at Docs/cddl1.txt
#  or http://www.opensolaris.org/os/licensing.
#  See the License for the specific language governing permissions
#  and limitations under the License.
#
# CDDL HEADER END
#
###########################################################################


use POSIX qw(uname);
use File::Basename;
use Getopt::Std;
use Socket;

my $ASver = 'v0.1.7';                   # script version
my $scriptName = basename($0);
my $kernel = '';
my $host = '';
my $trash = '';
my $capcmd = '';
my $intsel = '';
my $hexVal = '';
my $iface = '';
my $timeout = 60;
my $ptype = 'CDP';
my $pval = "and \\\('ether[20:2] = 0x2000' or ethertype 0x8100\\\)";
my $crunch = '01:00:0c:cc:cc:cc';
my $pktpid;
my $cmdcap;
getopts('hvxi:t:clsb:d', \ my %opts);

sub errOut {
        my $errCode = $_[0];
        my $errMsg = $_[1];
        if (${errMsg}) {
                print STDERR "${errMsg}\n";
        }
        if (${errCode} !~ m/^--$/) {
                print STDERR "\nSee \'${scriptName} -h\' for usage!\n" if $errCode > 10;
                exit $errCode;
        }
}

sub helpOut {
        print <<XxX1280256354xXx;

${scriptName} looks for LDP (Link Discovery Protocol) packets to determine
    the device connected to, device type, and interface port; assumes the
    availability of snoop on Solaris or tcpdump on Linux / FreeBSD.
        (${scriptName} can run on other OSes if '-b' is used
         to specify the path to either snoop or tcpdump.)


Usage:  ${scriptName} [ -h ]
        ${scriptName} [ -v ]
        ${scriptName} < -i interface > [ -t TIMEOUT ] [ -c | -l ] [ -d ]
                     [ -x [ -s ]] [ -b BINARY ]

    -h              This help output.
    -v              Display ${scriptName} version and exit
    -x              verbose output
    -s              extra verbose (useful for LLDP); requires -x
    -i interface    Specify network interface to listen on or the packet
                        capture file to read from (required)
    -t TIMEOUT      Set the timeout to listen for LDP packets (default 60 sec)
    -c              Look for CDP packets; mutually exclusive to -l (default)
    -l              Look for LLDP packets; mutually exclusive to -c (optional)
    -d              Display the command that would be run but without
                        actually doing so
    -b BINARY       /path/to/BINARY/executable to run to capture LDP packets;
                        ${scriptName} only knows how to handle output from
                        snoop and tcpdump

XxX1280256354xXx

        errOut(10);
}

helpOut() if defined($opts{h});
errOut(1, "${scriptName} version:  ${ASver}") if defined($opts{v});
errOut(21, "No network interface specified!") if ! defined($opts{i});
$timeout = $opts{t} if ((defined($opts{t})) && ($opts{t} =~ m/^\d+$/));
errOut(22, "Options '-c' and '-l' are mutually exclusive!\n") if ((defined($opts{c})) && (defined($opts{l})));

if ($opts{c}) {
        $ptype = 'CDP';
        #$pval = '0x2000';
        #$crunch = 'ether[20:2] =';
        $pval = "and \\\('ether[20:2] = 0x2000' or ethertype 0x8100\\\)";
        $crunch = '01:00:0c:cc:cc:cc';
}
if ($opts{l}) {
        $ptype = 'LLDP';
        $pval = '0x88cc';
        $crunch = 'ether proto';
}

$verbose = 1280547175 if $opts{x};
$excess = 1282682711 if $opts{s} && $opts{x};

($kernel, $host, $trash, $trash, $trash) = uname();

if ($opts{b}) {
        if (-x $opts{b}) {
                $capcmd = $opts{b};
        } else {
                errOut(27, "$opts{b} is not executable!");
        }
} else {
        if (($kernel =~ m/SunOS/) && (! $opts{b})) {
                $capcmd = '/usr/sbin/snoop';
        } elsif ($kernel =~ m/(Linux|FreeBSD)/) {
                $capcmd = '/usr/sbin/tcpdump';
        } else {
                errOut(20, "${scriptName} only knows how to handle Solaris, Linux, and FreeBSD OS types!\n  Otherwise, you must specify the path to \"snoop\" or \"tcpdump\" using \'-b\'.");
        }
}

$cmdcap = basename(${capcmd});

if ($capcmd =~ m/snoop/) {
        $intsel = '-d';
        $intsel = '-i' if -f $opts{i};
        $hexVal = '-x0';
        $pstart0 = 12;
        if ($ptype =~ m/CDP/) {
                $cver = 22;
                $pstart0 = 26;
        } elsif ($ptype =~ m/LLDP/) {
                $crunch = 'ethertype';
        }
} elsif ($capcmd =~ m/tcpdump/) {
        $intsel = '-i';
        $intsel = '-r' if -f $opts{i};
        $pstart0 = 12;
        if ($ptype =~ m/CDP/) {
                $pstart0 = 26;
                $hexVal = '-xx';
                $cver = 22;
                $crunch = 'ether host 01:00:0c:cc:cc:cc';
                $pval = "and \\\('ether[20:2] = 0x2000' or 'ether[12:2] = 0x8100'\\\)";
        } elsif ($ptype =~ m/LLDP/) {
                $hexVal = '-XX';
        }
} else {
        errOut(26, "${scriptName} only knows how to handle snoop or tcpdump output!");
}

$fullcmd = "${capcmd} $intsel $opts{i} -s 1524 ${hexVal} -c 1 ${crunch} ${pval} 2>&1";


errOut(2, "Command to run:\n  ${fullcmd}") if $opts{d};

$iface = $opts{i};
sub pktWatch {
        my $watchCmd = $_[0];
        my $intface = $_[1];
        my $pktLine = '';
        my $outPkt = '';
        my @feverish = ();
        $pktpid = open (TEKCAP, "${watchCmd} |") || errOut(24, "Execution error!");
        while ($pktLine = <TEKCAP>) {
                chomp $pktLine;
                errOut(24, "Unknown network interface: $intface") if $pktLine =~ m/: No such /;
                # only grab packet detail lines and strip off the leading byte
                # count data
                next unless $pktLine =~ m/(^\s+\d+:\s+\w+|^\s+\d+x\w+:\s+\w+)/;
                $pktLine =~ s/(^\s+\d+:\s+|^\s+\d+x\w+:\s+|\s{4}.*$|\s{2}.*$)//g;
                $outPkt = $pktLine if $pktLine;
                push(@feverish, $outPkt);
        }
        close TEKCAP;
        return(@feverish);
}

# set our process group in case we need to kill our spawn due to timeout
setpgrp(0,0);
eval {
        local $SIG{ALRM} = sub { die "TIMEOUT" };
        print STDERR "Watching for ${ptype} packet on $iface for ${timeout} seconds...\n";
        alarm($timeout);
        @packet = pktWatch("${fullcmd}", $iface);
        alarm(0);
};

# if we hit our timeout value, kill our children (tcpdump / snoop processes)
if ($@ =~ m/TIMEOUT/) {
        local $SIG{HUP} = 'IGNORE';
        kill (HUP, -$$);
        errOut(23, "\nTimed out waiting on data!\n  \(If ${scriptName} wasn't able to reap its children, you may have to kill\n  ${cmdcap} in the process table. Look for any children of the ${scriptName}\n  spawned process, PID ${pktpid}, if they exist.\)");
}

# setup pdata array, breaking out 2 char bytes from each line of data in
# packet array so that we can reference specific bytes without hassle
$btcnt = 0;
foreach $pline (@packet) {
        foreach $trace (split(/\s/, $pline)) {
                while ($trace =~ /(..)/g) {
                        @pdata[$btcnt] = $1;
                        $btcnt++;
                }
        }
}

my %pktHash;
if ($ptype =~ m/CDP/) {
        if ("${pdata[12]}${pdata[13]}" =~ m/8100/) {
                        
                $cver = 26;
                $pstart0 = 30;
                $pcp = $vlanid = sprintf("%16b", hex("${pdata[14]}${pdata[15]}"));
                #print "-:: $pcp : $vlanid ::-\n";
                $pcp = substr($pcp, 0, 3);
                $vlanid = substr($vlanid, -12);
                #print "-:: $pcp : $vlanid ::-\n";
                $pcp = oct("0b${pcp}");
                $vlanid = oct("0b${vlanid}");
                #print "-:: $pcp : $vlanid ::-\n";
                $pktHash{'priority'} = ${pcp};
                $pktHash{'vlanID'} = ${vlanid};
        }
        $CDPversion = hex(${pdata[$cver]});
        $pktHash{'CDPversion'} = ${CDPversion};
} elsif ($ptype =~ m/LLDP/) {
        $pstart0 = 14;
        if ("${pdata[12]}${pdata[13]}" !~ m/88cc/) {
                if ("${pdata[18]}${pdata[19]}" =~ m/88cc/) {
                        $pstart0 = 20;
                } else {
                        errOut(30, "Can't find $ptype ethertype start!");
                }
        }
}

# get 'device ID', 'platform', 'port ID', 'capabilities',
#     'VTP Management Domain', 'Native VLAN', 'duplex'

sub cdpDecode {
        my $lavp0 = $_[0];
        my $lavp1 = $_[1];
        my $pktType = $_[2];
        my $hunt = '';
        $pktType = "device-id" if $pktType =~ m/0001/;
        $pktType = "port-id" if $pktType =~ m/0003/;
        $pktType = "capabilities" if $pktType =~ m/0004/;
        $pktType = "sw-version" if $pktType =~ m/0005/;
        $pktType = "platform" if $pktType =~ m/0006/;
        $pktType = "vtp-mgmt-dom" if $pktType =~ m/0009/;
        $pktType = "native-vlan" if $pktType =~ m/000a/;
        $pktType = "duplex" if $pktType =~ m/000b/;
        $pktType = "mgmt-address" if $pktType =~ m/0016/;

        if ($pktType !~ m/^000/) {
                while ($lavp0 <= $lavp1) {
                        if ($pktType =~ m/duplex/) {
                                $hunt = "Half";
                                $hunt = "Full" if ${pdata[${lavp0}]} == 1;
                        } elsif ($pktType =~ m/capabilities/) {
                                $hunt = "";
                                if (hex(${pdata[${lavp0}]}) & 0x01) { $hunt .= "L3R(router)\t" ; }
                                if (hex(${pdata[${lavp0}]}) & 0x02) { $hunt .= "L2TB(bridge)\t" ; }
                                if (hex(${pdata[${lavp0}]}) & 0x04) { $hunt .= "L2SRB(bridge)\t" ; }
                                if (hex(${pdata[${lavp0}]}) & 0x08) { $hunt .= "L2SW(switch)\t" ; }
                                if (hex(${pdata[${lavp0}]}) & 0x10) { $hunt .= "L3TXRX(host)\t" ; }
                                if (hex(${pdata[${lavp0}]}) & 0x20) { $hunt .= "IGMP(snooping)\t" ; }
                                if (hex(${pdata[${lavp0}]}) & 0x40) { $hunt .= "L1(repeater)\t" ; }
                        } elsif ( $pktType =~ m/mgmt-address/ ) {
                                $hunt .= ${pdata[${lavp0}]};
                        } else {
                                # character conversions of decimal vals from hex vals
                                $hunt .= chr(hex(${pdata[${lavp0}]})) if $pktType !~ m/native-vlan/;
                                $hunt .= ${pdata[${lavp0}]} if $pktType =~ m/native-vlan/;
                        }
                        $lavp0++;
                }
                # decimal val of combined hex vals
                $hunt = hex(${hunt}) if $pktType =~ m/native-vlan/;
                # ios-version (sw-version) is several char strings in full, reduce to first one.
                if ( $pktType =~ m/sw-version/ ) {
                        @tokens = split (/\n/,$hunt);
                        $hunt = @tokens[0];
                } elsif ( $pktType =~ m/mgmt-address/ ) {
                        $token = substr($hunt,-8,8);
                        $hunt = inet_ntoa( pack ("N", hex ($token)));
                }
        }
        
        return($pktType, $hunt);
}

sub lldpDecode {
        my $lavp0 = $_[0];
        my $lavp1 = $_[1];
        my $pktType = $_[2];
        my $hunt = '';
        my $subType = '';
        my $oui = '';
        my $tlen = '';
        my $delt = '';
        my $dcnt = '';
        my $cntd = 1;
        $pktType = "device-id" if $pktType =~ m/^1$/;
        $pktType = "port-id" if $pktType =~ m/^2$/;
        $pktType = "portDesc" if $pktType =~ m/^4$/;
        $pktType = "sysName" if $pktType =~ m/^5$/;
        $pktType = "platform" if $pktType =~ m/^6$/;
        $pktType = "capabilities" if $pktType =~ m/^7$/;
        $pktType = "mgmt-address" if $pktType =~ m/^8$/;
        $pktType = "orgSpec" if $pktType =~ m/^127$/;
        if ($pktType =~ m/^mgmt-address$/) {
                #if (${pdata[${lavp0}]} =~ m/^05$/) {
                if (${pdata[${lavp0}]} == 0x05) {
                        # type 01 => IPv4;  32 bit => 4 octets; type + addr len = 0x05
                        $subType = 'IPv4';
                        $delt = '.';
                        $dcnt = '1';
                } elsif (${pdata[${lavp0}]} == 0x11) {
                        # type 02 => IPv6;  128 bit => 16 octets; type + addr len = 0x11
                        $subType = 'IPv6';
                        $delt = ':';
                        $dcnt = '2';
                } elsif (${pdata[${lavp0}]} == 0x07) {
                        # type 06 => 802 HWaddr;  48 bit hex => 6 octets; type + addr len = 0x07
                        $subType = 'hwaddr';
                        $delt = ':';
                        $dcnt = '1';
                }
                $lavp1 = $lavp0 + hex(${pdata[${lavp0}]});
                $lavp0 += 2;
                while ($lavp0 <= $lavp1) {
                        while ($cntd <= $dcnt) {
                                if ($subType =~ m/IPv4/) {
                                        $hunt .= hex(${pdata[${lavp0}]});
                                } else {
                                        $hunt .= ${pdata[${lavp0}]};
                                }
                                $cntd++;
                        }
                        if (($cntd >= $dcnt) && ($lavp0 < $lavp1)) {
                                $cntd = 1;
                                $hunt .= "${delt}";
                        }
                        $lavp0++;
                }
        }
        if ($pktType =~ m/^(portDesc|sysName|platform)$/) {
                $subType = 'val';
                while ($lavp0 <= $lavp1) {
                        # character conversions of decimal vals from hex vals
                        $hunt .= chr(hex(${pdata[${lavp0}]}));
                        $lavp0++;
                }
        } elsif ($pktType =~ m/^capabilities$/) {
                # only care about capabilities (1st 2 octets), not enabled capabilities (2nd 2 octets)
                # stop parsing before 2nd set
                $lavp1 -= 2;
                $subType = 'val';
                while ($lavp0 <= $lavp1) {
                        # 802.1AB-2005
                        #if (hex(${pdata[${lavp0}]}) & 0x0000) { $hunt .= "other\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0001) { $hunt .= "L1(repeater)\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0002) { $hunt .= "L2(bridge)\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0004) { $hunt .= "L3(WLAN AP)\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0008) { $hunt .= "L3R(router)\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0010) { $hunt .= "telephone\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0020) { $hunt .= "DOCSIS cable dev\t" ; }
                        #if (hex(${pdata[${lavp0}]}) & 0x0040) { $hunt .= "station only\t" ; }
                        # 802.1AB-2009
                        if (hex(${pdata[${lavp0}]}) & 0x0001) { $hunt .= "other\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0002) { $hunt .= "L1(repeater)\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0004) { $hunt .= "L2(bridge)\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0008) { $hunt .= "L3(WLAN AP)\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0010) { $hunt .= "L3R(router)\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0020) { $hunt .= "telephone\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0040) { $hunt .= "DOCSIS cable dev\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0080) { $hunt .= "station only\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0100) { $hunt .= "L2(C-VLAN)\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0200) { $hunt .= "L2(S-VLAN)\t" ; }
                        if (hex(${pdata[${lavp0}]}) & 0x0400) { $hunt .= "L2(2 port MAC relay)\t" ; }
                        $lavp0++;
                }
        } elsif ($pktType =~ m/^(device-id|port-id)$/) {
                if ($pktType =~ m/device-id/) {
                        $subType = "chassis component" if ${pdata[${lavp0}]} == 1;
                        $subType = "ifalias" if ${pdata[${lavp0}]} == 2;
                        $subType = "port component" if ${pdata[${lavp0}]} == 3;
                        $subType = "hwaddr" if ${pdata[${lavp0}]} == 4;
                        $subType = "netaddr" if ${pdata[${lavp0}]} == 5;
                        $subType = "ifName" if ${pdata[${lavp0}]} == 6;
                        $subType = "local" if ${pdata[${lavp0}]} == 7;
                } else {
                        $subType = "ifalias" if ${pdata[${lavp0}]} == 1;
                        $subType = "port component" if ${pdata[${lavp0}]} == 2;
                        $subType = "hwaddr" if ${pdata[${lavp0}]} == 3;
                        $subType = "netaddr" if ${pdata[${lavp0}]} == 4;
                        $subType = "ifName" if ${pdata[${lavp0}]} == 5;
                        $subType = "circuit ID" if ${pdata[${lavp0}]} == 6;
                        $subType = "local" if ${pdata[${lavp0}]} == 7;
                }
                $lavp0++;
                if ($subType =~ m/hwaddr/) {
                        while ($lavp0 <= $lavp1) {
                                $hunt .= ${pdata[${lavp0}]} . ":";
                                $lavp0++;
                        }
                        $hunt =~ s/:$//g;
                } elsif ($subType =~ m/netaddr/) {
                        while ($lavp0 <= $lavp1) {
                                $hunt .= hex(${pdata[${lavp0}]}) . ".";
                                $lavp0++;
                        }
                        $hunt =~ s/\.$//g;
                } else {
                        while ($lavp0 <= $lavp1) {
                                $hunt .= chr(hex(${pdata[${lavp0}]}));
                                $lavp0++;
                        }
                }
        } elsif ($pktType =~ m/orgSpec/) {
                foreach $xtcnt (1 .. 3) {
                        $oui .= ${pdata[${lavp0}]};
                        $lavp0++;
                }
                if ($oui =~ m/0080c2/) {
                        $subType = 'native-vlan' if ${pdata[${lavp0}]} == 1;
                        $subType = 'vlanName' if ${pdata[${lavp0}]} == 3;
                        $lavp0++;
                        if ($subType =~ m/native-vlan/) {
                                while ($lavp0 <= $lavp1) {
                                        $hunt .= ${pdata[${lavp0}]};
                                        $lavp0++;
                                }
                                $hunt = hex($hunt);
                        } elsif ($subType =~ m/vlanName/) {
                                $lavp0 += 3;
                                while ($lavp0 <= $lavp1) {
                                        $hunt .= chr(hex(${pdata[${lavp0}]}));
                                        $lavp0++;
                                }
                        }
                }
        }
        return($pktType, $subType, $hunt);
}

if ($ptype =~ m/CDP/) {
        if ($verbose) {
                @outArr = qw(device-id platform sw-version capabilities port-id duplex vtp-mgmt-dom mgmt-address native-vlan CDPversion priority vlanID);
                # priority, vlanID set earlier immediately after packet cap.
        } else {
                @outArr = qw(device-id port-id);
        }
        foreach my ${xcnt} (0 .. 14) {          # loop thru 8 times
                $pstart1 = $pstart0 + 1;        # start byte x0 and x1
                $pstartv = "${pdata[${pstart0}]}${pdata[${pstart1}]}";
                $plens0 = $pstart0 + 2;         # length starts at byte x2
                $plens1 = $plens0 + 1;          #   and ends at byte x3
                                                # length value is dec val of
                                                #   plens[0-1] - 4 bytes
                $plenv = (hex("${pdata[${plens0}]}${pdata[${plens1}]}")) - 4;
                $pval0 = $plens0 + 2;           # value is 2 bytes after length st
                $pval1 = $pval0 + $plenv - 1;   # value ends at length - 1
                if ($pstartv =~ m/^(0001|0003|0004|0005|0006|0009|000a|000b|0016)$/) {
                        # (pktTypeName, pktTypeVal) = cdpDecode(valSt, valEnd, vals)
                        ($pvalv0, $pvalv1) = cdpDecode($pval0, $pval1, $pstartv);
                        $pktHash{$pvalv0} = "${pvalv1}";
                }
                # move to next set of bytes in packet
                $pstart0 = $pval1 + 1;
        }
} elsif ($ptype =~ m/LLDP/) {
        if ($verbose) {
                @outArr = qw(device-id platform capabilities port-id portDesc sysName mgmt-address orgSpec);
        } else {
                @outArr = qw(device-id port-id);
        }
        foreach my ${xcnt} (1 .. 50) {          # loop thru 50 times which
                                                #   is unreasonable but due
                                                #   to laziness and orgSpec
                                                #   this can be > 10; we will
                                                #   break out at 'end of llpdu'
                $pstart1 = $pstart0 + 1;        # start byte x0 and x1
                $binput = unpack("B16", pack("H16", "${pdata[${pstart0}]}${pdata[${pstart1}]}"));
                $binput =~ /(.......)(.........)/;
                $idTyp = oct("0b$1");
                $idLen = oct("0b$2");
                $pval0 = $pstart0 + 2;
                $pval1 = $pval0 + $idLen - 1;
                if ($idTyp =~ m/^(1|2|4|5|6|7|8|127)$/) {
                        ($pvalv0, $pvalv1, $pvalv2) = lldpDecode($pval0, $pval1, $idTyp);
                        $pktHash{$pvalv0}{$pvalv1} = "${pvalv2}";
                }
                $pstart0 = $pval1 + 1;
                last if $idTyp == 0;
        }
}

if ($ptype =~ m/CDP/) {
        foreach $zilch (@outArr) {
                print "  ${zilch}:\t$pktHash{$zilch}\n" if $pktHash{$zilch};
        }
} elsif ($ptype =~ m/LLDP/) {
        foreach $zilch (@outArr) {
                foreach $hcliz (keys %{$pktHash{$zilch}}) {
                        if ($excess) {
                                printf("%12s:  %17s:  %s\n", $zilch, $hcliz, $pktHash{$zilch}{$hcliz}) if $pktHash{$zilch}{$hcliz};
                        } else {
                                if ($zilch !~ m/^orgSpec$/) {
                                        print "  ${zilch}:\t$pktHash{$zilch}{$hcliz}\n" if $pktHash{$zilch};
                                } else {
                                        if ($hcliz) {
                                                print "  ${hcliz}:\t$pktHash{$zilch}{$hcliz}\n" if $pktHash{$zilch};
                                        }
                                }
                        }
                }
        }
}
