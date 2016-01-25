#!usr/bin/perl
# LiteratureAssociationsNeo4j.pl
# Geoffrey Hannigan
# Patrick Schloss Lab
# University of Michigan

# WARNING: This is reading off of the disk, which
# needs to be changed to memory to improve performance.

# Set use
use strict;
use warnings;
# Use the neo4j module to facilitate interaction
use REST::Neo4p;
# For documentation and whatnot
use Getopt::Long;
use Pod::Usage;
# And because I like timing myself
my $start_run = time();

# Set variables
my $opt_help;
my $output;
my $input;
my $flag = 0;
my $n1;
my $n2;
my $sequence;
my $formatVar;

# Startup the neo4j connection using default location
eval {
    REST::Neo4p->connect('http://127.0.0.1:7474');
};
ref $@ ? $@->rethrow : die $@ if $@;

# Set the options
GetOptions(
    'h|help' => \$opt_help,
    'o|output=s' => \$output,
    'i|input=s' => \$input
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

# Open files
open(IN, "<$input") || die "Unable to read in $input: $!";
#open(OUT, ">$output") || die "Unable to write to $output: $!";

# Parse the input and save into neo4j
foreach my $line (<IN>) {
    chomp $line;
    # Start the script by resetting the flag for each iteraction
    # within the file
    if ($line =~ /^ID\s/) {
        print STDOUT "Resetting counter...\n";
        $flag = 0;
        $n1 = 0;
        $n2 = 0;
        $formatVar = 0;
        next;
    } elsif ($flag =~ 0 & $line =~ /^OS\s+(\w.+$)/) {
        print STDOUT "Phage is $1\n";
        $n1 = REST::Neo4p::Node->new( 
            {Name => $1},
            {Organism => 'Phage'} );
        $flag = 1;
        next;
    } elsif ($flag =~ 1 & $line =~ /host=\"(.+)\"/) {
        print STDOUT "Host is $1\n";
        $n2 = REST::Neo4p::Node->new( 
            {Name => $1},
            {Organism => 'Bacterial_Host'} );
        $n1->relate_to($n2, 'Infects');
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
        $n1->set_property({ Sequence => $sequence });
        $flag = 1;
        $sequence = 0;
    } else {
        next;
    }
}

# See how long it took
my $end_run = time();
my $run_time = $end_run - $start_run;
print STDERR "Processed the file in $run_time seconds.\n";
