#!/usr/bin/perl
# 说明：此脚本可以考虑作为监控、研发人员的login shell
#yum install perl-Switch.noarch  -y 
#Cmnd_Alias ALERT_USER_CMD = /usr/bin/netstat,/usr/sbin/ss,/usr/sbin/dmidecode,/usr/bin/lastb,/sbin/fdisk -l,/sbin/lvs,/sbin/vgs,/sbin/pvs,/bin/du
#monitor    ALL=(ALL)   NOPASSWD: ALERT_USER_CMD
 
use strict;
use Switch;
use Cwd;
use Term::ANSIColor;
use Sys::Hostname;
use File::Basename;
my $host = hostname;
my $command;

$ENV{'PATH'}='/bin:/usr/sbin:/usr/bin';
$SIG{'INT'} = sub { } ; 

my @allow_command=(
    "/bin/cat",
    "/usr/bin/sar",
    "/bin/date",
    "/usr/bin/pgrep",
    "/bin/dmesg",
    "/bin/echo",
    "/bin/grep",
    "/bin/hostname",
    "/bin/ls",
    "/bin/netstat",
    "/bin/ping",
    "/bin/ps",
    "/bin/rpm",
    "/bin/sleep",
    "/bin/sort",
    "/bin/uname",
    "cd",
    "/sbin/fdisk",
    "/sbin/ifconfig",
    "/sbin/lvs",
    "/sbin/pvs",
    "/sbin/route",
    "/sbin/vgs",
    "/bin/df",
    "/usr/bin/atop",
    "/usr/bin/clear",
    "/usr/bin/dig",
    "/usr/bin/dstat",
    "/usr/bin/du",
    "/usr/bin/file",
    "/usr/bin/free",
    "/usr/bin/htop",
    "/usr/bin/id",
    "/usr/bin/iostat",
    "/usr/bin/lastb",
    "/usr/bin/less",
    "/usr/bin/md5sum",
    "/usr/bin/mpstat",
    "/usr/bin/nslookup",
    "/usr/bin/rpm",
    "/usr/bin/ss",
    "/usr/bin/stat",
    "/usr/bin/tail",
    "/usr/bin/telnet",
    "/usr/bin/top",
    "/usr/bin/uniq",
    "/usr/bin/uptime",
    "/usr/bin/vmstat",
    "/usr/bin/w",
    "/usr/bin/who",
    "/usr/bin/whoami",
    "/usr/bin/zabbix_get",
    "/usr/bin/zgrep",
    "/usr/bin/zless",
    "/usr/sbin/dmidecode",
);
 
my @allow_command2=map {basename("$_") } @allow_command;
 
sub help() {
    print "Available commands:\n";
    print $_."\n" foreach (@allow_command);
}
 
system("/usr/bin/clear");
 
sub get_command() {
    print "\n";
    my $pwd = cwd(); 
    print "[";
    print color("green"), "monitor\@$host $pwd", color("reset");
    print "]\$ ";
    my $input_command=<STDIN>;
    chomp($input_command);
    return $input_command;
}
 
while ("1") {
    my $command = get_command(); 
    next if $command eq '';
    if ($command =~ /^\s*(\.|\\|\[|\])/) {
        print "Permission denied.\n";
        next;
    }
 
    exit if ($command =~ /^(quit|exit)$/);
    if ($command eq "help") {
        &help;
        next;
    }
 
    if ($command eq "ifconfig") {
        system("/sbin/ifconfig");
        next;
    }

    if ($command eq "ll") {
        system("/bin/ls --color -l ");
        next;
    }
 
    if ($command =~ m#^systemctl status [a-z\-]+$#) {
        system("$command"); 
        next; 
    }

    my ($binary,undef)=split /[\s+|\|]/,"$command";

    if ($command =~ m#[|&><;]#) {
        print "Sorry, I/O redirection or pipe or background process is denied. \n";
        next;
    }
   
    # Unmatched [ in regex; 
    if (grep m/^$binary\b/,@allow_command or grep m/^$binary\b/,@allow_command2 or $binary =~ m#/etc/init\.d/#) {
        chomp($binary);
        if ($binary =~ /(lastb|netstat|ss|pvs|lvs|vgs|dmidecode|du)/ and $binary ne "less") {
            system("/usr/bin/sudo $command");
        } elsif ($binary =~ /fdisk/) {
            system("/usr/bin/sudo /sbin/fdisk -l");
        } elsif ($binary =~ /ls/) {
            $command =~ s/ls/ls --color/;
            system("$command");
        } elsif ($binary =~ m#/etc/init\.d/#) {
            system("$binary status");
        } elsif ($binary eq "cd") {
            my $newdir=(split /\s+/,"$command")[1];
            if ($newdir ne '') {
                chdir($newdir);
            } else {
                chdir();
            }
        } else {
            system("$command");
            # sleep 0.1 second
            select(undef,undef,undef,0.1); 
        }
    } else {
        print "Sorry, unknown command '$binary', please run 'help' to show all the avaiable commands.\n";
    }
}
