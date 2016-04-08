#! /bin/bash
# GetCrisprPhagePairs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set the Environment #
#######################
WorkingDirectory=$(pwd)
export Output='tmp'

export BinPath=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/bin/
export OpenMet=/scratch/pschloss_flux/ghannig/git/OpenMetagenomeToolkit/bin/
export BlastPath=/scratch/pschloss_flux/ghannig/bin/ncbi-blast-2.3.0+/bin/

export PilerData=${1}
export PhageGenomes=${2}
export OutputFile=${3}

# Set working dir
echo CRISPR pair script is working in "${WorkingDirectory}"...
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
perl ${OpenMet}LengthFilterSeqs.pl -i ./${Output}/Spacers.fa -o ./${Output}/Spacers.good.fa -m 20 -n 65
# Output should be Spacers.good.fa

# Get rid of spaces in the files
sed 's/ /_/g' "${PhageGenomes}" > ./${Output}/PhageReferenceNoSpace.fa || exit
sed 's/ /_/g' ./${Output}/Spacers.good.fa > ./${Output}/SpacersNoSpaceGood.fa || exit

# Blastn the spacers against the phage genomes
${BlastPath}makeblastdb \
		-dbtype nucl \
		-in ./${Output}/PhageReferenceNoSpace.fa \
		-out ./${Output}/PhageGenomeDatabase \
		|| exit

${BlastPath}blastn \
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

