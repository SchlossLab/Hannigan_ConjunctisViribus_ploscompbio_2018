#!usr/bin/perl
# LiteratureAssociationsNeo4j.pl
# Geoffrey Hannigan
# Patrick Schloss Lab
# University of Michigan

# NOTE: Don't need an output file for this since the
# neo4j connected database is the output

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
my $FullName;
my $Genus;
my $Species;
my $formname = 0;
my $Spacer;
my $crispr;
my $PhageTarget;
my $PercentID;
my $array1;
my $array2;
my $uniprot;
my $relate;
my $phage;
my $bacteria;
my $phageForm;
my $bacteriaForm;
my $blast;
my $pfam;
my $SpacerForm;
my $PhageTargetForm;

# Startup the neo4j connection using default location
# Be sure to set username and password as neo4j
# User = 2nd value, PW = 3rd value
eval {
    REST::Neo4p->connect('http://127.0.0.1:7474');
};
ref $@ ? $@->rethrow : die $@ if $@;

# Set the options
GetOptions(
    'h|help' => \$opt_help,
    'i|input=s' => \$input,
    'c|crispr=s' => \$crispr,
    'u|uniprot=s' => \$uniprot,
    'b|blast=s' => \$blast,
    'p|pfam=s' => \$pfam
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

# Open files
open(IN, "<$input") || die "Unable to read in $input: $!";
open(CRISPR, "<$crispr") || die "Unable to read in $crispr: $!";
open(UNIPROT, "<$uniprot") || die "Unable to read in $uniprot: $!";
open(BLAST, "<$blast") || die "Unable to read in $blast: $!";
open(PFAM, "<$pfam") || die "Unable to read in $pfam: $!";

print STDERR "\n\n\nProgress: Adding Literature Data.\n";

# Parse the input and save into neo4j
# Get the literature data
foreach my $line (<IN>) {
    chomp $line;
    # Start the script by resetting the flag for each iteraction
    # within the file
    if ($line =~ /^ID\s/) {
        print STDERR "Resetting counter...\n";
        $flag = 0;
        $n1 = 0;
        $n2 = 0;
        $formatVar = 0;
        $formname = 0;
        next;
    } elsif ($flag =~ 0 & $line =~ /^OS\s+(\w.+$)/) {
        # File really should already be without spaces though
        ($formname = $1) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        print STDERR "Phage is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
        $flag = 1;
        next;
    } elsif ($flag =~ 1 & $line =~ /host=\"(.+)\"/) {
        ($FullName = $1) =~ s/\s/_/g;
        print STDERR "Host is $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        # Remove all non-standard characters from the variable names
        # now that underscore delimiter is not being used
        $FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Genus =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Species =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        print STDERR "Host genus is $Genus\n";
        print STDERR "Host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
        $n1->relate_to($n2, 'Infects_Literature');
    # } elsif ($flag =~ 1 && $line =~ /^\s+([agct\s]+[agct])\s+[0-9]+$/) {
    #     $formatVar = $1;
    #     $formatVar =~ s/\s//g;
    #     $sequence = $formatVar;
    #     $flag = 2;
    # } elsif ($flag =~ 2 && $line =~ /^\s+([agct\s]+[agct])\s+[0-9]+$/) {
    #     $formatVar = $1;
    #     $formatVar =~ s/\s//g;
    #     $sequence = $sequence.$formatVar;
    # } elsif ($flag =~ 2 && $line =~ /^\/\//) {
    #     #$n1->set_property({ Sequence => $sequence });
    #     $flag = 1;
    #     $sequence = 0;
    } else {
        next;
    }
}

sub AddGenericFile () {
    # Import file handle
    my $fileInput = shift;
    foreach my $line (<CRISPR>) {
        chomp $line;
        $line =~ s/^(\S+)_\d+\t/$1\t/g;
        $Spacer = (split /\t/, $line)[0];
        $PhageTarget = (split /\t/, $line)[1];
        $PercentID = (split /\t/, $line)[2];
        # Remove illegal characters
        ($SpacerForm = $Spacer) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        ($PhageTargetForm = $PhageTarget) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        # print STDERR "SpacerForm host is $SpacerForm.\n";
        # print STDERR "Phage target is $PhageTargetForm.\n";
        my @n11 = REST::Neo4p->get_nodes_by_label( $PhageTargetForm );
        my @n12 = REST::Neo4p->get_nodes_by_label( $SpacerForm );
    
        # Create new phage target node if it does not exist
        unless (@n11) {
            $formname = $PhageTargetForm;
            # print STDERR "New CRISPR phage target is $formname\n";
            $n1 = REST::Neo4p::Node->new( {Name => $formname} );
            $n1->set_property( {Organism => 'Phage'} );
            $n1->set_labels('Phage',$formname);
        }
        unless (@n12) {
            ($FullName = $Spacer) =~ s/\s/_/g;
            # print STDERR "New spacer host is $FullName\n";
            $Genus = (split /_/, $FullName)[0];
            $Species = $Genus."_".(split /_/, $FullName)[1];
            # Remove all non-standard characters from the variable names
            # now that underscore delimiter is not being used
            $FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
            $Genus =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
            $Species =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
            # print STDERR "CRISPR host genus is $Genus\n";
            # print STDERR "CRISPR host species is $Species\n";
            $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
            $n2->set_property( {Genus => $Genus} );
            $n2->set_property( {Species => $Species} );
            $n2->set_property( {Organism => 'Bacterial_Host'} );
            $n2->set_labels('Bacterial_Host',$FullName);
        }
    
        print STDERR "SpacerForm host is $SpacerForm.\n";
    
        # Then get the newly created nodes as arrays
        @n11 = REST::Neo4p->get_nodes_by_label( $PhageTargetForm );
        @n12 = REST::Neo4p->get_nodes_by_label( $SpacerForm );
    
        while( $array1 = pop @n11 ) {
            while( $array2 = pop @n12 ) {
                $array1->relate_to($array2, 'Infects_CRISPR');
            }
        }
    }
}

print STDERR "\n\n\nProgress: Adding CRISPRs.\n";

# Add in the CRISPR match data
foreach my $line (<CRISPR>) {
    chomp $line;
    $line =~ s/^(\S+)_\d+\t/$1\t/g;
    $Spacer = (split /\t/, $line)[0];
    $PhageTarget = (split /\t/, $line)[1];
    $PercentID = (split /\t/, $line)[2];
    # Remove illegal characters
    ($SpacerForm = $Spacer) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    ($PhageTargetForm = $PhageTarget) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    # print STDERR "SpacerForm host is $SpacerForm.\n";
    # print STDERR "Phage target is $PhageTargetForm.\n";
    my @n11 = REST::Neo4p->get_nodes_by_label( $PhageTargetForm );
    my @n12 = REST::Neo4p->get_nodes_by_label( $SpacerForm );

    # Create new phage target node if it does not exist
    unless (@n11) {
        $formname = $PhageTargetForm;
        # print STDERR "New CRISPR phage target is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
    }
    unless (@n12) {
        ($FullName = $Spacer) =~ s/\s/_/g;
        # print STDERR "New spacer host is $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        # Remove all non-standard characters from the variable names
        # now that underscore delimiter is not being used
        $FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Genus =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Species =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        # print STDERR "CRISPR host genus is $Genus\n";
        # print STDERR "CRISPR host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
    }

    print STDERR "SpacerForm host is $SpacerForm.\n";

    # Then get the newly created nodes as arrays
    @n11 = REST::Neo4p->get_nodes_by_label( $PhageTargetForm );
    @n12 = REST::Neo4p->get_nodes_by_label( $SpacerForm );

    while( $array1 = pop @n11 ) {
        while( $array2 = pop @n12 ) {
            $array1->relate_to($array2, 'Infects_CRISPR');
        }
    }
}

print STDERR "\n\n\nProgress: Adding BLAST results.\n";

foreach my $line (<UNIPROT>) {
    chomp $line;
    $phage = (split /\t/, $line)[0];
    $bacteria = (split /\t/, $line)[1];
    ($phageForm = $phage) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    ($bacteriaForm = $bacteria) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    # print STDERR "Phage host is $phageForm.\n";
    # print STDERR "Bactera target is $bacteriaForm.\n";
    my @n11 = REST::Neo4p->get_nodes_by_label( $phageForm );
    my @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );

    # Create new phage target node if it does not exist
    unless (@n11) {
        $formname = $phageForm;
        # print STDERR "New CRISPR phage target is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
    }
    unless (@n12) {
        ($FullName = $bacteria) =~ s/\s/_/g;
        # print STDERR "New phage host is $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        # Remove all non-standard characters from the variable names
        # now that underscore delimiter is not being used
        $FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Genus =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Species =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        # print STDERR "CRISPR host genus is $Genus\n";
        # print STDERR "CRISPR host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
    }

    print STDERR "Phage predator is $phageForm.\n";

    # Then get the newly created nodes as arrays
    @n11 = REST::Neo4p->get_nodes_by_label( $phageForm );
    @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );

    while( $array1 = pop @n11 ) {
        while( $array2 = pop @n12 ) {
            $array1->relate_to($array2, 'Infects_Uniprot');
        }
    }
}

print STDERR "\n\n\nProgress: Adding Predicted Pfam Interactions.\n";

foreach my $line (<BLAST>) {
    chomp $line;
    $phage = (split /\t/, $line)[0];
    $bacteria = (split /\t/, $line)[1];
    ($phageForm = $phage) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    ($bacteriaForm = $bacteria) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    # print STDERR "Phage blast is $phageForm.\n";
    # print STDERR "Bactera blast is $bacteriaForm.\n";
    my @n11 = REST::Neo4p->get_nodes_by_label( $phageForm );
    my @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );

    # Create new phage target node if it does not exist
    unless (@n11) {
        $formname = $phageForm;
        # print STDERR "New BLAST phage is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
    }
    unless (@n12) {
        ($FullName = $bacteria) =~ s/\s/_/g;
        print STDERR "New BLAST bacteria is $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        # Remove all non-standard characters from the variable names
        # now that underscore delimiter is not being used
        $FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Genus =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Species =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        # print STDERR "CRISPR host genus is $Genus\n";
        # print STDERR "CRISPR host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
    }

    print STDERR "Phage predator is $phageForm.\n";

    # Then get the newly created nodes as arrays
    @n11 = REST::Neo4p->get_nodes_by_label( $phageForm );
    @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );

    while( $array1 = pop @n11 ) {
        while( $array2 = pop @n12 ) {
            $array1->relate_to($array2, 'Infects_Blast');
        }
    }
}

print STDERR "\n\n\nProgress: Adding Predicted Pfam Interactions.\n";

foreach my $line (<PFAM>) {
    chomp $line;
    $phage = (split /\t/, $line)[0];
    $bacteria = (split /\t/, $line)[1];
    ($phageForm = $phage) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    ($bacteriaForm = $bacteria) =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
    # print STDERR "Phage predator is $phage.\n";
    # print STDERR "Bactera host is $bacteria.\n";
    my @n11 = REST::Neo4p->get_nodes_by_label( $phageForm );
    my @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );

    # Create new phage target node if it does not exist
    unless (@n11) {
        $formname = $phageForm;
        # print STDERR "New Pfam phage is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
    }
    unless (@n12) {
        ($FullName = $bacteria) =~ s/\s/_/g;
        # print STDERR "New Pfam bacteria $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        # Remove all non-standard characters from the variable names
        # now that underscore delimiter is not being used
        $FullName =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Genus =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        $Species =~ s/[^A-Z^a-z^0-9^\t]+/_/g;
        # print STDERR "CRISPR host genus is $Genus\n";
        # print STDERR "CRISPR host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
    }

    print STDERR "Phage predator is $phageForm.\n";

    # Then get the newly created nodes as arrays
    @n11 = REST::Neo4p->get_nodes_by_label( $phageForm );
    @n12 = REST::Neo4p->get_nodes_by_label( $bacteriaForm );

    while( $array1 = pop @n11 ) {
        while( $array2 = pop @n12 ) {
            $array1->relate_to($array2, 'Infects_Pfam');
        }
    }
}

# See how long it took
my $end_run = time();
my $run_time = $end_run - $start_run;
print STDERR "Processed the file in $run_time seconds.\n";
