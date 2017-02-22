#!/usr/bin/perl
use strict;
use Sys::Hostname;

my $zabbix_server="127.0.0.1";
my $zabbix_port="10051";

# specify the host name
my $host = hostname;

my $current_time=`date +%s`;
chomp($current_time);

my $log_size_file;
my @array=qw(
/var/log/secure
/var/log/messages
/var/log/haproxy.log
);

system("/usr/bin/zabbix_sender -z $zabbix_server -p $zabbix_port -s $host -k 'log_check[alive]' -o 'alive' ");

sub log_filter {
    my $count_oom=0;
    my $count_dev=0;
    my $count_ssh=0;
    my $count_50x=0;
    my $count_backup=0;

    #
    my $skip;
    my $file=$_[0];
    my $position_file=$_[1];
    my $last_modify_time=0;
    
    print $file."\n";
    open (FH, "< $file") or die $!;

    # get log size
    my $filesz=-s $file;

    if ( -f $position_file ) {
        $skip = `cat $position_file`;
        $last_modify_time=(stat($log_size_file))[9];

        # make sure we don't read old logs too much....
        if (($current_time - $last_modify_time) > 300) {
            print "too old\n";
            $skip = $filesz;
            open (FH2,"> $position_file");
            print FH2 "$filesz\n";
            print "new position - $filesz\n";
            exit 1;
        } else {
            if ($skip > $filesz) {
                print "file truncated....\n";
                $skip = tell(FH);
            } else {
                chomp $skip;
                print "seeking---\n";
            }
        }

    } else {
        # we don't care about old logs, avoid giving wrong alerts
        open (FH2,"> $position_file");
        print FH2 "$filesz\n"; 
        close(FH2);
        return 
    }

    
    print "Starting with : $skip \n";
    seek FH,$skip,0; 
    

    if ($file =~ /messages$/) {
        while (<FH>) {
            if (/Out of memory/) {
                #print;
                $count_oom++;
                next;
            }

            if (m#(bus|disk|I/O|device|SCSI|kernel) (error|panic|failure|failed)#i) {
                #print;
                $count_dev++;
                next;
            }
        }
        system("/usr/bin/zabbix_sender -z $zabbix_server -p $zabbix_port -s $host -k 'log_check[sys.oom]' -o $count_oom ");
        system("/usr/bin/zabbix_sender -z $zabbix_server -p $zabbix_port -s $host -k 'log_check[sys.dev]' -o $count_dev ");
    }

    if ($file =~ /secure$/) {
        while (<FH>) {
            if (/Failed password for/) {
                #print;
                $count_ssh++;
                next;
            }
        }
        system("/usr/bin/zabbix_sender -z $zabbix_server -p $zabbix_port -s $host -k 'log_check[ssh.brute]' -o $count_ssh ");
    } else {
        while (<FH>) {
            if (/ 50[2-5] /) {
                #print;
                $count_50x++;
                next;
            }
        }
        system("/usr/bin/zabbix_sender -z $zabbix_server -p $zabbix_port -s $host -k 'log_check[web.50x]' -o $count_50x ");
    }

    # send zabbix data to remote

    open (FH2,"> $position_file");
    print FH2 "$filesz\n"; 
    close(FH2);
}

########
foreach my $log (@array) {
    print ">>>>>> $log\n";
    if ( ! -f $log ) {
        system("/usr/bin/zabbix_sender -z $zabbix_server -p $zabbix_port -s $host -k 'log_check[alive]' -o 'log file not found' ");
        next;
    }
    
    # replace the file name
    my $log_file=$log;
    $log_file =~ s#^/##;
    $log_file =~ s#/#_#g;
    $log_size_file="/tmp/$log_file";
    
    # 
    &log_filter($log,$log_size_file);
    print "-" x 80 ."\n";
}
