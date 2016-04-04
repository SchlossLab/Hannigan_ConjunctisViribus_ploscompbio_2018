#!usr/bin/perl
# dat2fasta.pl
# Geoffrey Hannigan
# Patrick Schloss Lab
# University of Michigan

# NOTE: Im going to just crank this out without a hash but
# for speed I will want to write it with one.

# Set use
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
# And because I like timing myself
my $start_run = time();

# Set variables
my $opt_help;
my $input;
my $output;
my $flag;
my $formatVar;
my $sequence;
my $prot = '';
my $line;

# Set the options
GetOptions(
    'h|help' => \$opt_help,
    'd|datInput=s' => \$input,
    'f|fastaOutput=s' => \$output,
    'p|prot' => \$prot
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

# Open files
open(IN, "<$input") || die "Unable to read in $input: $!";
open(OUT, ">$output") || die "Unable to write to $output: $!";

if ($prot) {
    foreach $line (<IN>) {
        chomp $line;
        # Start the script by resetting the flag for each iteraction
        # within the file
        if ($line =~ /^ID\s+(\S+)\s/) {
            my $SaveVariable = $1;
            $flag = 0;
            $formatVar = 0;
    		$sequence = 0;
            next;
        } elsif ($flag =~ 0 & $line =~ /^AC\s+(\w.+)\;$/) {
            print OUT ">sp\|$1\|$SaveVariable ";
            $flag = 0;
            next;
        } elsif ($flag =~ 0 & $line =~ /^OS\s+(\w.+$)/) {
            print OUT "$1\n";
            $flag = 1;
            next;
        } elsif ($flag =~ 1 && $line =~ /^\s+([A-Z\s]+[A-Z\s])$/) {
            $formatVar = $1;
            $formatVar =~ s/\s//g;
            $sequence = $formatVar;
            $flag = 2;
        } elsif ($flag =~ 2 && $line =~ /^\s+([A-Z\s]+[A-Z\s])$/) {
            $formatVar = $1;
            $formatVar =~ s/\s//g;
            $sequence = $sequence.$formatVar;
        } elsif ($flag =~ 2 && $line =~ /^\/\//) {
            print OUT "$sequence\n";
        } else {
            next;
        }
    }
} else {
    foreach $line (<IN>) {
        chomp $line;
        # Start the script by resetting the flag for each iteraction
        # within the file
        if ($line =~ /^ID\s/) {
            print STDERR "Resetting counter...\n";
            $flag = 0;
            $formatVar = 0;
            $sequence = 0;
            next;
        } elsif ($flag =~ 0 & $line =~ /^OS\s+(\w.+$)/) {
            print STDERR "Name is $1\n";
            print OUT "\>$1\n";
            $flag = 1;
            next;
        } elsif ($flag =~ 1 && $line =~ /^\s+([agct\s]+[agct])\s+[0-9]+$/) {
            $formatVar = $1;
            $formatVar =~ s/\s//g;
            $sequence = $formatVar;
            $flag = 2;
        } elsif ($flag =~ 2 && $line =~ /^\s+([agct\s]+[agct])\s+[0-9]+$/) {
            $formatVar = $1;
            $formatVar =~ s/\s//g;
            $sequence = $sequence.$formatVar;
        } elsif ($flag =~ 2 && $line =~ /^\/\//) {
            print OUT "$sequence\n";
        } else {
            next;
        }
    }
}

close(IN);
close(OUT);

# See how long it took
my $end_run = time();
my $run_time = $end_run - $start_run;
print STDERR "Conversion completed in $run_time seconds.\n";
