#!usr/bin/bash
# GetCrisprPhagePairs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set the Environment #
#######################
export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='CRISPR'

export ProjectBin=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/bin/
export MothurProg=/share/scratch/schloss/mothur/mothur

export PilerData=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/PilerResult.txt
export PhageGenomes=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/phageSVA.fa

# Set working dir
cd ${WorkingDirectory}
mkdir ./${Output}

################################
# Blast Spacers Against Phages #
################################
# Get the spacer sequences from the Piler-CR CRISPR output
perl ${ProjectBin}ExtractSpacers.pl -i ${PilerData} -o ./${Output}/Spacers.fa

# Filter the spacer sequences by length
${MothurProg} "#screen.seqs(fasta=./${Output}/Spacers.fa, minlength=30, maxlength=45)"
# Output should be Spacers.good.fa

# Get rid of spaces in the files
sed 's/ /_/g' ${PhageGenomes} > ./${Output}/PhageReferenceNoSpace.fa
sed 's/ /_/g' ./${Output}/Spacers.good.fa > ./${Output}/SpacersNoSpaceGood.fa

# Blastn the spacers against the phage genomes
makeblastdb \
		-dbtype nucl \
		-in ./${Output}/PhageReferenceNoSpace.fa \
		-out ./${Output}/PhageGenomeDatabase

blastn \
    	-query ./${Output}/SpacersNoSpaceGood.fa \
    	-out ./${Output}/SpacerMatches.blast \
    	-db ./${Output}/PhageGenomeDatabase \
    	-outfmt 6
