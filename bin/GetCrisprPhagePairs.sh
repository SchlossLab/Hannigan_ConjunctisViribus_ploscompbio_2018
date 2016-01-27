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


################################
# Blast Spacers Against Phages #
################################
# Get the spacer sequences from the Piler-CR CRISPR output
perl ${ProjectBin}ExtractSpacers.pl -i ${PilerData} -o ./${Output}/Spacers.fa

# Filter the spacer sequences by length
${MothurProg} "#screen.seqs(fasta=./${Output}/Spacers.fa, , minlength=30, maxlength=45)"
# Output should be Spacers.good.fa

# Blastn the spacers against the phage genomes
makeblastdb \
		-dbtype nucl \
		-in ${PhageGenomes} \
		-out ./${Output}/PhageGenomeDatabase

blastn \
    	-query ./${Output}/Spacers.good.fa \
    	-out ./${Output}/SpacerMatches.blast \
    	-db ./${Output}/PhageGenomeDatabase \
    	-outfmt 6
    	-evalue 1e-50
