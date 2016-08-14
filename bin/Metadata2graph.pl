#!usr/bin/perl
# Metadata2graph.pl
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
my $metadata;

# Set the options
GetOptions(
	'h|help' => \$opt_help,
	's|samples=s' => \$samples,
	'm|metadata=s' => \$metadata
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

open(my $SAMPLES, "<", "$samples") || die "Unable to read in $samples: $!";
open(my $META, "<", "$metadata") || die "Unable to read in $metadata: $!";

my $phageid = 0;
my $abund = 0;
my $sampleid = 0;
my $n1;

foreach my $line (<$SAMPLES>) {
	chomp $line;
	$phageid = (split /\t/, $line)[0];
	print "$phageid\n";
	$abund = (split /\t/, $line)[1];
	$sampleid = (split /\t/, $line)[2];

	my @n11 = REST::Neo4p->get_nodes_by_label( $sampleid );
	my @n12 = REST::Neo4p->get_nodes_by_label( $phageid );
	print scalar(@n12)."\n";

	# Ensure there are no duplicated nodes
    die "You have duplicate sample node IDs: $!" if (scalar(@n11) gt 1);
    die "You have duplicate phage node IDs: $!" if (scalar(@n12) gt 1);
    next if (scalar(@n12) eq 0);

	unless (@n11) {
		$n1 = REST::Neo4p::Node->new( {Name => $sampleid} );
		$n1->set_property( {Organism => 'SampleID'} );
		$n1->set_labels('SampleID',$sampleid);
	}

	@n11 = REST::Neo4p->get_nodes_by_label( $sampleid );
	@n12 = REST::Neo4p->get_nodes_by_label( $phageid );
	print scalar(@n11)."\n";
	print scalar(@n12)."\n";

	my $array1 = pop @n11;
    my $array2 = pop @n12;

	# Ensure there are no duplicated nodes
    die "You have duplicate sample node IDs: $!" if (scalar(@n11) gt 1);
    die "You have duplicate phage node IDs: $!" if (scalar(@n12) gt 1);

	$array1->relate_to($array2, 'Sampled')->set_property({Abundance => $abund});
}

my $disease;

foreach my $line (<$META>) {
	chomp $line;
	$sampleid = (split /\t/, $line)[0];
	print "$sampleid\n";
	$disease = (split /\t/, $line)[2];

	my @n11 = REST::Neo4p->get_nodes_by_label( $sampleid );
	my @n12 = REST::Neo4p->get_nodes_by_label( $disease );
	print scalar(@n12)."\n";

	# Ensure there are no duplicated nodes
    die "You have duplicate sample node IDs: $!" if (scalar(@n11) gt 1);
    die "You have duplicate disease node IDs: $!" if (scalar(@n12) gt 1);
    next if (scalar(@n11) eq 0);

    unless (@n12) {
		$n1 = REST::Neo4p::Node->new( {Name => $disease} );
		$n1->set_property( {Organism => 'Disease'} );
		$n1->set_labels('Disease',$disease);
	}

	@n11 = REST::Neo4p->get_nodes_by_label( $sampleid );
	@n12 = REST::Neo4p->get_nodes_by_label( $disease );
	print scalar(@n11)."\n";
	print scalar(@n12)."\n";

	my $array1 = pop @n11;
    my $array2 = pop @n12;

	# Ensure there are no duplicated nodes
    die "You have duplicate sample node IDs: $!" if (scalar(@n11) gt 1);
    die "You have duplicate phage node IDs: $!" if (scalar(@n12) gt 1);

	$array2->relate_to($array1, 'Diseased')->set_property({Disease => "TRUE"});
}




