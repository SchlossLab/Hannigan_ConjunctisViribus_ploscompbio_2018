#!usr/bin/perl
# AddPredictedRelationships.pl
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

print STDERR "Adding predicted relationships to interaction network\n";

eval {
	REST::Neo4p->connect('http://localhost:7474/',"neo4j","neo4j");
};
ref $@ ? $@->rethrow : die $@ if $@;

# Set variable
my $opt_help;
my $input;

# Set the options
GetOptions(
	'h|help' => \$opt_help,
	'i|input=s' => \$input
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

# Open files
open(my $IN, "<", "$input") || die "Unable to read in $input: $!";

foreach my $line (<$]IN>) {
	chomp $line;
	my $bacteria = (split /\t/, $line)[0];
	print "$bacteria\n";
	my $Phage = (split /\t/, $line)[1];
	print "$Phage\n";
	my $interaction = (split /\t/, $line)[2];
	print "$interaction\n";
	# Remove illegal characters
	(my $bacteriaForm = $bacteria) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
	(my $PhageForm = $Phage) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
	my @n11 = REST::Neo4p->get_nodes_by_label( $PhageForm );
	my @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );
	# Ensure there are no duplicated nodes
	die "You dont have only one phage node ID: $!" unless (scalar(@n11) eq 1);
	die "You dont have only one duplicate bacteria node ID: $!" unless (scalar(@n12) eq 1);
	# Get nodes into scalar variables
	my $array1 = pop @n11;
	my $array2 = pop @n12;

	# Determine whether relationship exists
	my @phage_reln = $array1->get_outgoing_relationships();
	my $flag = 0;
	foreach my $RelnItr (@phage_reln) {
		my $PhageNode = $RelnItr->start_node;
		my $BacteriaNode = $RelnItr->end_node;
		if ($PhageNode eq $array1 && $BacteriaNode eq $array2) {
			$flag = 1;
			my $relnHit = $RelnItr;
			last;
		} else {
			next;
		}
	}

	if ($flag eq 0) {
			# This means I need to create a new relationship
			$array1->relate_to($array2, 'PredictedInteraction')->set_property({'Prediction' => $interaction});
		} else {
			next;
	}

}

# See how long it took
my $end_run = time();
my $run_time = $end_run - $start_run;
print STDERR "Processed the file in $run_time seconds.\n";
