#!/usr/bin/perl
use strict;
#use warnings;
use Geo::IP;
my $gi = Geo::IP->open("/usr/share/GeoIP/GeoIPCity.dat", GEOIP_STANDARD);

my $log_file=$ARGV[0];
my $filename = $log_file;
my $ip_num=35;
my $url_num=35;
my %ip_hash;
my %url_hash;
my %status_hash;
my %domain_hash; 
 
open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";
 
while (my $row = <$fh>) {
    my @array=split(/\s+/,$row);
    my $ip=$array[3];
    my $url=$array[8];
    my $status=$array[2];

    if ($ip ne '' and $ip ne '-') {
        $ip_hash{$ip}=$ip_hash{$ip}+1;
        $url_hash{$url}=$url_hash{$url}+1;
        $status_hash{$status}=$status_hash{$status}+1;
    }
}

my $i=0;
print "-" x 80 . "\n";
printf "| %-6s | %-30s |\n", "Count", "HTTP Status";
print "-" x 80 . "\n";
for my $key ( reverse sort { $status_hash{$a} <=> $status_hash{$b} } keys %status_hash ) {
    if ($i < 10) {    
        #print "$key => $status_hash{$key}\n";
        printf "| %-6d | %-30s |\n",$status_hash{$key} , $key ; 
        $i++;
    } else {
        last; 
    }
}

print "-" x 80 . "\n";
printf "| %-6s | %-30s | %-40s | \n", "Count", "IP ADDRESS", "Location";
print "-" x 80 . "\n";
$i=0;
for my $key ( reverse sort { $ip_hash{$a} <=> $ip_hash{$b} } keys %ip_hash ) {
    if ($i < $ip_num ) {    
        #print "$key => $ip_hash{$key}\n";
        my $record = $gi->record_by_addr("$key");
        my $location;
        eval { 
            $location = $record->country_name . "/" . $record->region_name . "/" . $record->city;
        };
        if ($@) {
            $location = 'N/A';
        }
        printf "| %-6d | %-30s | %-40s | \n",$ip_hash{$key} , $key, $location ; 
        $i++;
    } else {
        last; 
    }
}

print "-" x 160 . "\n";
printf "| %-6s | %-172s |\n", "Count", "URL";
print "-" x 160 . "\n";
$i=0;
for my $key ( reverse sort { $url_hash{$a} <=> $url_hash{$b} } keys %url_hash ) {
    if ($i < $url_num) {    
        #next if $key =~ /cron_|some_cronb|favicon.ico/;
        printf "| %-6d | %-172s |\n",$url_hash{$key} , substr($key,0,172) ; 
        $i++;
    } else {
        last; 
    }
}
