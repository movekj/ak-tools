#!/usr/bin/perl
my $file = $ARGV[0] || "/var/log/php-fpm/www-slow.log"; 
my $threshold = 5;
my %hash_script;
my %hash_time;
my $reset;
my $read_next;
my $pre_script;

if ($ARGV[0] eq '-h' or $ARGV[0] eq '--help') {
    print "Usage: $0 <php-fpm slow log>\n"; 
    exit 1;
}

open (FH, "< $file") or die $!;
while (my $line = <FH>) {
    # skip some php pages
    chomp($line);
    #next if ($line =~ /script_filename.*(asyncs|cron)/);
    if ($line =~ /\[(.*? \d{2}:\d{2}):\d{2}\].*pid \d+$/) { 
        $hash_time{$1} = $hash_time{$1} + 1;
    }elsif ($line =~ /script_filename = (.*)$/) {
        $hash_script{$1}{'number'} = $hash_script{$1}{'number'} + 1;
        $pre_script=$1; 
        $read_next=1;
    }elsif ($read_next == 1) {
        if ($line =~ /\[\w+?\] (.*)/) {
            $hash_script{$pre_script}{'function'}{$1}[0] = $hash_script{$pre_script}{'function'}{$1}[0] + 1;
            #print "$pre_script\n";
            #print "$1\n";
            $read_next=0;
        }
    }
}

for my $date (sort keys %hash_time) {
    print "$date $hash_time{$date}\n";
}

my $i=0;
for my $script ( sort {$hash_script{$b}{'number'} <=> $hash_script{$a}{'number'} } keys %hash_script) {
    printf (" >>>>> PHP页面:\033[1;33m %s \033[0m执行缓慢，累计\033[1;33m %d \033[0m次。\n",$script,$hash_script{$script}{'number'}) if $i < 10; 
    for my $fun (keys % {$hash_script{$script}{'function'}} ) {
        if ($hash_script{$script}{'function'}{$fun}[0] > $threshold) {
            printf ("       > 涉及函数: %s ，累计 %d 次。\n",$fun, $hash_script{$script}{'function'}{$fun}[0]) if $i < 10; 
        }
    }
    $i++;
}
