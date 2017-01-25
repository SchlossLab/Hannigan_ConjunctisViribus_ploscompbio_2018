#!usr/bin/perl
# length2graph.pl
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

# Startup the neo4j connection using default location
# Be sure to set username and password as neo4j
# User = 2nd value, PW = 3rd value
eval {
	REST::Neo4p->connect('http://127.0.0.1:7474', "neo4j", "neo4j");
};
ref $@ ? $@->rethrow : die $@ if $@;

my $opt_help;
my $samples;

# Set the options
GetOptions(
	'h|help' => \$opt_help,
	's|samples=s' => \$samples
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

open(my $SAMPLES, "<", "$samples") || die "Unable to read in $samples: $!";

my $phageid = 0;
my $abund = 0;
my $sampleid = 0;
my $n1;

foreach my $line (<$SAMPLES>) {
	chomp $line;
	$phageid = (split /\t/, $line)[0];
	print "Cluster ID is $phageid\n";
	$abund = (split /\t/, $line)[1];
	print "Length is $abund\n";

	my @n12 = REST::Neo4p->get_nodes_by_label( $phageid );
	# print scalar(@n12)."\n";

	# Ensure there are no duplicated nodes
    die "There are multiple cluster nodes for $phageid: $!" if (scalar(@n12) gt 1);
    print "There is no cluster node for $phageid. Probably had no recorded interactions: $!" if (scalar(@n12) lt 1);

    my $n2 = pop @n12;
    $n2->set_property( {Length => $phageid} );
}
