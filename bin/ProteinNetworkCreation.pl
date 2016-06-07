#! /usr/bin/perl
# ProteinNetworkCreation.pl
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
	REST::Neo4p->connect('http://localhost:7474/', "neo4j", "neo4j");
};
ref $@ ? $@->rethrow : die $@ if $@;

# Set variables
my $opt_help;
my $phage;
my $bacteria;
my $dat;
my $n1;
my $n2;
my $flag;
my $formatVar;
my $formname;

# Set the options
GetOptions(
	'h|help' => \$opt_help,
	'b|bacteria=s' => \$bacteria,
	'p|phage=s' => \$phage,
	'd|dat=s' => \$dat
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

open(my $BACTERIA, "<", "$bacteria") || die "Unable to read in $bacteria: $!";
my $bacterialinecount = 0;
$bacterialinecount++ while <$BACTERIA>;
print STDERR "Bacteria line count is $bacterialinecount\n";
open(my $PHAGE, "<", "$phage") || die "Unable to read in $phage: $!";
my $phagelinecount = 0;
$phagelinecount++ while <$PHAGE>;
print STDERR "Bacteria line count is $phagelinecount\n";
open(my $DAT, "<", "$dat") || die "Unable to read in $dat: $!";

# Reset the files
seek $BACTERIA, 0, 0;
seek $PHAGE, 0, 0;

sub AddNodes {
	my ($fileInput, $label, $linecount) = @_;
	my $progcounter = 0;
	my $progress = 0;
	while (my $line = <$fileInput>) {
		$progress = 100 * $progcounter / $linecount;
		print STDERR "\rNodes Processed: $progress\%";
		++$progcounter;
		chomp $line;
		$line =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
		my $uniqueid = (split /\t/, $line)[0];
		my $clusterid = (split /\t/, $line)[1];
		my $acc = (split /\t/, $line)[2];
		my $name = (split /\t/, $line)[3];
		my $protname = (split /\t/, $line)[4];
		my $percentid = (split /\t/, $line)[5];
	
		$n1 = REST::Neo4p::Node->new( {UniqueID => $uniqueid} );
		$n1->set_property( {ClusterID => $clusterid} );
		$n1->set_property( {Acccession => $acc} );
		$n1->set_property( {Name => $name} );
		$n1->set_property( {ProtName => $protname} );
		$n1->set_property( {PercentID => $percentid} );
		$n1->set_property( {Organism => $label} );
		$n1->set_property( {DataType => "ReferenceGenes"} );
		$n1->set_labels($label,$name);
		if ($label eq "Bacteria") {
			my $Genus = (split /_/, $name)[0];
			my $Species = $Genus."_".(split /_/, $name)[1];
			$n1->set_property( {Genus => $Genus} );
			$n1->set_property( {Species => $Species} );
		}
	}
}

# Run the subroutines
print STDERR "\nPROGRESS: Creating Phage Nodes.\n";
# AddNodes(\*$PHAGE, "Phage", $phagelinecount);
print STDERR "\nPROGRESS: Creating Bacteria Nodes.\n";
# AddNodes(\*$BACTERIA, "Bacteria", $bacterialinecount);
print STDERR "\nPROGRESS: Establishing Relationships.\n";

my @phagenodes;
my @bacterianodes;

while (my $line = <$DAT>) {
	print STDOUT "Running loop\n";
	chomp $line;
	if ($line =~ /^ID\s/) {
		$flag = 0;
		$n1 = 0;
		$n2 = 0;
		$formatVar = 0;
		$formname = 0;
		next;
	} elsif ($flag =~ 0 & $line =~ /^OS\s+(\w.+$)/) {
		# File really should already be without spaces though
		($formname = $1) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
		print STDOUT "$formname\n";
		@phagenodes = REST::Neo4p->get_nodes_by_label( $formname );
		$flag = 1;
		next;
	} elsif ($flag =~ 1 & $line =~ /host=\"(.+)\"/) {
		(my $FullName = $1) =~ s/\s/_/g;
		$FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
		print STDOUT "$FullName\n";
		my @bactrianodes = REST::Neo4p->get_nodes_by_label( $FullName );
		foreach my $phagenode (@phagenodes) {
			foreach my $bacterianode (@bacterianodes) {
				$phagenode->relate_to($bacterianode, 'LinkedGenes')->set_property({Literature => "TRUE"})
			}
		}
	} else {
		next;
	}
}
