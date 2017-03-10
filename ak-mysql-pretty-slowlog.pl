#!/usr/bin/perl
# Usage: ak-mysql-pretty-slowlog.pl slow.log

my $file = $ARGV[0];

open (FH, "< $file") or die $!;
while (my $line = <FH>) {
    next if ($line =~ /^SET timestamp/);
    chomp($line);
    # Time:
    if ($line =~ /^# Time/) {
        $line =~ s/# Time: (\d{2})(\d{2})(\d{2})/# Time: \033[1;32m20$1\/$2\/$3\033[0m/;
        $line =~ s/(\d+:\d+:\d+)$/\033[1;32m$1\033[0m/;
        print "$line ";
    } elsif ( $line =~ /# User/) {
        $line =~ s/# User\@Host: (\S+)\[\S+\] @  \[(\S+)\].*$/\($1 \/ $2\)/;
        print "$line\n"; 
    } elsif ( $line =~ /# Query_time: (\d+.\d+)/) {
        if ($1 < 2.0) {
            $line =~ s/# Query_time: (\d+.\d+)/# Query_time: \033[1;34m$1\033[0m/;
        } elsif ($1 > 2.0 and $1 < 5.0) {
            $line =~ s/# Query_time: (\d+.\d+)/# Query_time: \033[1;33m$1\033[0m/;
        } else {
            $line =~ s/# Query_time: (\d+.\d+)/# Query_time: \033[1;31m$1\033[0m/;
        }
        print "$line\n";
    } else {
        $line =~ s/(AND|ALTER|AS|ASC|BETWEEN|BY|COLUMNS|DELETE|DESC|FROM|FULL|GROUP|INSERT|JOIN|LEFT|LIMIT|ORDER|RIGHT|SELECT|SHOW|SQL_CALC_FOUND_ROWS|UNIX_TIMESTAMP|UPDATE|VALUES|WHERE) / \033[1;36m$1\033[0m /ig;
        print "$line\n";
    }
}
