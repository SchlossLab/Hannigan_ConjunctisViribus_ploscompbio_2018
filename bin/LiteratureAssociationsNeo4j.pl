#!usr/bin/perl
# LiteratureAssociationsNeo4j.pl
# Geoffrey Hannigan
# Patrick Schloss Lab
# University of Michigan

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
    if ($flag =~ 0 & $line =~ /^OS\s+(\w.+$)/) {
        print STDOUT "Phage is $1\n";
        $n1 = REST::Neo4p::Node->new( 
            {Name => $1},
            {Organism => 'Phage'} );
        $flag = 1;
    } elsif ($flag =~ 1 & $line =~ /host=\"(.+)\"/) {
        print STDOUT "Host is $1\n";
        $n2 = REST::Neo4p::Node->new( 
            {Name => $1},
            {Organism => 'Bacterial_Host'} );
        $n1->relate_to($n2, 'Infects');
        $flag = 0;
    } elsif ($flag =~ 1 && $line =~ /^OS\s+(\w.+$)/) {
        print STDOUT "There was no host.\n";
        print STDOUT "Phage is $1\n";
    }
}

# See how long it took
my $end_run = time();
my $run_time = $end_run - $start_run;
print STDERR "Processed the file in $run_time seconds.\n";
