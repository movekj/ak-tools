#!/usr/bin/perl
use strict;
my $filename="/tmp/redis_stats.txt";
my $redis_host="841c93cabf1046ca.redis.rds.aliyuncs.com";
my $redis_port=6379;
my $redis_pass="yfV91Xnl5p";
my @array_ip;
my $call_total = 0;
my $sec_total = 0;

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

`redis-cli -h $redis_host -p $redis_port -a $redis_pass INFO Commandstats | grep -v "#" > $filename`;

open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";

while (my $row = <$fh>) {
    chomp $row;
    my @array=split(":|,|=",$row);
    my $cmd = $array[0];
    my $call = $array[2];
    my $sec = $array[4];
    my $psec = $array[6];
    $call_total += $call;
    $sec_total += $sec;
}

print "-" x 80 . "\n";
printf ("%-22s | %7s | %8s | %12s |\n","命令","调用占比","时间占比","单次调用耗时(ms)");
print "-" x 80 . "\n";

open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";
while (my $row = <$fh>) {
    chomp $row;
    my @array=split(":|,|=",$row);
    my $cmd = $array[0];
    my $call = $array[2];
    my $sec = $array[4];
    my $psec = $array[6];
    printf ("%-20s | %-.6s% | %-.8s% | %12s",$cmd,100*$call/$call_total,100*$sec/$sec_total,"$psec\n")
}
print "-" x 80 . "\n";
