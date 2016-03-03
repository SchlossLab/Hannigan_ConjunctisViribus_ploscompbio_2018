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
my $kmer;
my $relate;
my $phage;
my $bacteria;

# Startup the neo4j connection using default location
# Be sure to set username and password as neo4j
# User = 2nd value, PW = 3rd value
eval {
    REST::Neo4p->connect('http://127.0.0.1:7474','neo4j','neo4j');
};
ref $@ ? $@->rethrow : die $@ if $@;

# Set the options
GetOptions(
    'h|help' => \$opt_help,
    'i|input=s' => \$input,
    'c|crispr=s' => \$crispr,
    'k|kmer=s' => \$kmer
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

# Open files
open(IN, "<$input") || die "Unable to read in $input: $!";
open(CRISPR, "<$crispr") || die "Unable to read in $crispr: $!";
open(KMER, "<$kmer") || die "Unable to read in $kmer: $!";

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
        ($formname = $1) =~ s/\s/_/g;
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
        print STDERR "Host genus is $Genus\n";
        print STDERR "Host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
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
        #$n1->set_property({ Sequence => $sequence });
        $flag = 1;
        $sequence = 0;
    } else {
        next;
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
    print STDERR "Spacer host is $Spacer.\n";
    print STDERR "Phage target is $PhageTarget.\n";
    my @n11 = REST::Neo4p->get_nodes_by_label( $PhageTarget );
    my @n12 = REST::Neo4p->get_nodes_by_label( $Spacer );

    # Create new phage target node if it does not exist
    unless (@n11) {
        ($formname = $PhageTarget) =~ s/\s/_/g;
        print STDERR "New CRISPR phage target is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
    }
    unless (@n12) {
        ($FullName = $Spacer) =~ s/\s/_/g;
        print STDERR "New spacer host is $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        print STDERR "CRISPR host genus is $Genus\n";
        print STDERR "CRISPR host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
    }

    # Then get the newly created nodes as arrays
    @n11 = REST::Neo4p->get_nodes_by_label( $PhageTarget );
    @n12 = REST::Neo4p->get_nodes_by_label( $Spacer );

    while( $array1 = pop @n11 ) {
        while( $array2 = pop @n12 ) {
            $array2->relate_to($array1, 'CrisprTarget');
        }
    }
}

foreach my $line (<KMER>) {
    chomp $line;
    $phage = (split /\t/, $line)[0];
    $bacteria = (split /\t/, $line)[1];
    print STDERR "Phage host is $phage.\n";
    print STDERR "Bactera target is $bacteria.\n";
    my @n11 = REST::Neo4p->get_nodes_by_label( $phage );
    my @n12 = REST::Neo4p->get_nodes_by_label( $bacteria );

    # Create new phage target node if it does not exist
    unless (@n11) {
        ($formname = $phage) =~ s/\s/_/g;
        print STDERR "New CRISPR phage target is $formname\n";
        $n1 = REST::Neo4p::Node->new( {Name => $formname} );
        $n1->set_property( {Organism => 'Phage'} );
        $n1->set_labels('Phage',$formname);
    }
    unless (@n12) {
        ($FullName = $bacteria) =~ s/\s/_/g;
        print STDERR "New phage host is $FullName\n";
        $Genus = (split /_/, $FullName)[0];
        $Species = $Genus."_".(split /_/, $FullName)[1];
        print STDERR "CRISPR host genus is $Genus\n";
        print STDERR "CRISPR host species is $Species\n";
        $n2 = REST::Neo4p::Node->new( {Name => $FullName} );
        $n2->set_property( {Genus => $Genus} );
        $n2->set_property( {Species => $Species} );
        $n2->set_property( {Organism => 'Bacterial_Host'} );
        $n2->set_labels('Bacterial_Host',$FullName);
    }

    # Then get the newly created nodes as arrays
    @n11 = REST::Neo4p->get_nodes_by_label( $phage );
    @n12 = REST::Neo4p->get_nodes_by_label( $bacteria );

    while( $array1 = pop @n11 ) {
        while( $array2 = pop @n12 ) {
            $array2->relate_to($array1, 'UniprotInfects');
        }
    }
}

#print STDERR "\n\n\nProgress: Adding Tetramer Distances.\n";

# # Comment this out for now while I work on other things
# foreach my $line (<KMER>) {
#     chomp $line;
#     my $flag = 0;
#     my $origin = (split /\t/, $line)[0];
#     my $destination = (split /\t/, $line)[2];
#     my $score = (split /\t/, $line)[1];
#     print STDERR "Processing $origin\n" if ($origin eq $destination);
#     my @n11 = REST::Neo4p->get_nodes_by_label( $origin );
#     my @n12 = REST::Neo4p->get_nodes_by_label( $destination );
#     # Create new target node if it does not exist
#     unless (@n11) {
#         # Replace just in case, but spaces should be gone
#         ($formname = $origin) =~ s/\s/_/g;
#         print STDERR "New distance origin is $formname\n";
#         $n1 = REST::Neo4p::Node->new( {Name => $formname} );
#         $n1->set_property( {Organism => 'Phage'} );
#         $n1->set_labels('Phage',$formname);
#         $flag=1;
#     }
#     unless (@n12) {
#         ($formname = $destination) =~ s/\s/_/g;
#         print STDERR "New distance destination is $formname\n";
#         $n2 = REST::Neo4p::Node->new( {Name => $formname} );
#         $n2->set_property( {Organism => 'Phage'} );
#         $n2->set_labels('Phage',$formname);
#         $flag = $flag + 2;
#     }
#     # Then get the newly created nodes as arrays
#     if ($flag == 1) {
#         print STDERR "Relating new origin to old destination.\n";
#         while( $array2 = pop @n12) {
#             $relate = $n1->relate_to($array2, 'Tetramer');
#             $relate->set_property({ BrayCurtis => $score });
#         }
#     } elsif ($flag == 2) {
#         print STDERR "Relating new destination to old origin.\n";
#         while( $array1 = pop @n11) {
#             $relate = $array1->relate_to($n2, 'Tetramer');
#             $relate->set_property({ BrayCurtis => $score });
#         }
#     } elsif ($flag == 3) {
#         print STDERR "Relating new destination to new origin.\n";
#         $relate = $n1->relate_to($n2, 'Tetramer');
#         $relate->set_property({ BrayCurtis => $score });
#     }

#     while( $array1 = pop @n11 ) {
#         while( $array2 = pop @n12 ) {
#             $relate = $array2->relate_to($array1, 'Tetramer');
#             $relate->set_property({ BrayCurtis => $score });
#         }
#     }
# }


# See how long it took
my $end_run = time();
my $run_time = $end_run - $start_run;
print STDERR "Processed the file in $run_time seconds.\n";
