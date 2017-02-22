#!/usr/bin/perl
use strict;
my $filename=$ARGV[0];
my @array_ip;

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";

while (my $row = <$fh>) {
    chomp $row;
    $row =~ s/^\s+|\s+$//g;
    if($row =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ &&(($1<=255 && $2<=255 && $3<=255 && $4<=255 ))) {
        push @array_ip, "$1.$2.$3.0/24";
    } else {
        print "Invalid IP - $row\n";
    }
}

@array_ip = uniq(@array_ip);
foreach my $ip (@array_ip) {
    print "deny $ip;\n"; 
}
