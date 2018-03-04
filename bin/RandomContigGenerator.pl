#!/usr/bin/perl
# RandomContigGenerator.pl
# Pat Schloss Lab
# University of Michigan
# Geoffrey Hannigan

# Set use
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
# Timer
my $start_run = time();

# Set variables
my %FastaHash;
my $opt_help;
my $input;
my $output;
my $fastaInput;
my $FastaErrorCounter = 0;
my $FastaID;
my $length;
my $randLength;
my $randStart;
my $randContig;
my $lpercent;
my $percentlength;

# Set the options
GetOptions(
	'h|help' => \$opt_help,
	'i|input=s' => \$input,
	'o|output=s' => \$output,
	'p|percent=f' => \$lpercent
);

pod2usage(-verbose => 1) && exit if defined $opt_help;

open(IN, "<$input") || die "Unable to read $input: $!";
open(OUT, ">$output") || die "Unable to write to $output: $!";


sub ReadInFasta {
	print STDERR "Progress: Reading in fasta...\n";
	# Set the variable for the fasta input file
	my $fastaInput = shift;
	# Setup fasta hash to return at the end
	while (my $line = <$fastaInput>) {
		if ($line =~ /\>/ && $FastaErrorCounter == 0) {
			# print "Made it to ID!\n";
			chomp $line;
			$FastaID = $line;
			# Get rid of the arrow from the ID
			$FastaID =~ s/\>//;
			$FastaErrorCounter = 1;
		} elsif ($line =~ /\>/ && $FastaErrorCounter == 1) {
			die "KILLED BY BAD FASTA! There was no sequence before ID $line: $!";
		} elsif ($line !~ /\>/ && $FastaErrorCounter == 0) {
			print STDERR "Yikes, is this in block format? That is totally not allowed!\n";
			die "KILLED BY BAD FASTA! There was a missing ID: $!";
		} elsif ($line !~ /\>/ && $FastaErrorCounter == 1) {
			chomp $line;
			# Change out the lower case letters so they match the codon hash
			$line =~ s/g/G/g;
			$line =~ s/a/A/g;
			$line =~ s/c/C/g;
			$line =~ s/t/T/g;
			$FastaHash{$FastaID} = $line;
			$FastaErrorCounter = 0;
		}
	}
	return %FastaHash;
}

sub PullRandomContig {
	print STDERR "Progress: Randomly generating contigs...\n";
	my $fastaHash = shift;
	while (my ($fastaKey, $fastaSeq) = each(%{$fastaHash})) {
		$length = length($fastaSeq);
		$percentlength = $length * $lpercent;
		$randStart =  int(rand($length-$percentlength));
		$randLength = $percentlength;
		$randContig = substr($fastaSeq, $randStart, $randLength);
		print OUT "\>$fastaKey\n$randContig\n";
	}
}

my %Fasta = ReadInFasta(\*IN);
# print Dumper \%Fasta;
PullRandomContig(\%Fasta);

close(IN);
close(OUT);
