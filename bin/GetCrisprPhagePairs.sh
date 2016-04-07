#! /bin/bash
# GetCrisprPhagePairs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set the Environment #
#######################
WorkingDirectory=$(pwd)
export Output='tmptmp'

export BinPath=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/bin/
export MothurProg=/share/scratch/schloss/mothur/mothur

export PilerData=${1}
export PhageGenomes=${2}
export OutputFile=${3}

# Set working dir
echo CRISPR pair script is working in ${WorkingDirectory}...
mkdir ./${Output}

################################
# Blast Spacers Against Phages #
################################
# Get the spacer sequences from the Piler-CR CRISPR output
perl ${BinPath}ExtractSpacers.pl \
	-i "${PilerData}" \
	-o ./${Output}/Spacers.fa \
	|| exit

# Filter the spacer sequences by length
${MothurProg} "#screen.seqs(fasta=./${Output}/Spacers.fa, minlength=25, maxlength=50)"
# Output should be Spacers.good.fa

# Get rid of spaces in the files
sed 's/ /_/g' "${PhageGenomes}" > ./${Output}/PhageReferenceNoSpace.fa || exit
sed 's/ /_/g' ./${Output}/Spacers.good.fa > ./${Output}/SpacersNoSpaceGood.fa || exit

# Blastn the spacers against the phage genomes
makeblastdb \
		-dbtype nucl \
		-in ./${Output}/PhageReferenceNoSpace.fa \
		-out ./${Output}/PhageGenomeDatabase \
		|| exit

blastn \
    	-query ./${Output}/SpacersNoSpaceGood.fa \
    	-out ./${Output}/SpacerMatches.blast \
    	-db ./${Output}/PhageGenomeDatabase \
    	-outfmt 6 \
    	|| exit

# Get the Spacer ID, Phage ID, and Percent Identity
cut -f 1,2,3 ./${Output}/SpacerMatches.blast \
	| sed 's/_\d\+\t/\t/' \
	> "${OutputFile}" \
	|| exit

rm ./${Output}

