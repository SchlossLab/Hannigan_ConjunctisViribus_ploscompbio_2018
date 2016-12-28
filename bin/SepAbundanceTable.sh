#! /bin/bash
# SepAbundanceTable.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export metadata=$1
export bacterialcontigs=$2
export phagecontigs=$3
export bacterialabundout=$4
export phageabundout=$5
export abundancetable=$6

# Set tmp directory
export tmpdir=./data/tmpcat
mkdir ${tmpdir}

# Get list of sample IDs for each group
## Bacteria
echo Getting bacteria sample list...
cut -f 16,10 ${metadata} \
	| grep Bacteria \
	| awk '{ print $2 }' \
	> "${tmpdir}"/BacteriaSampleList.tsv

## VLP
echo Getting VLP sample list...
cut -f 16,10 ${metadata} \
	| grep VLP \
	| awk '{ print $2 }' \
	> "${tmpdir}"/PhageSampleList.tsv

# Get list of the contigs associated with each group
echo Getting list of bacteria contig IDs
egrep '>' ${bacterialcontigs} \
	| sed 's/>//' \
	> "${tmpdir}"/BacteriaContigList.tsv

echo Getting list of phage contig IDs
egrep '>' ${phagecontigs} \
	| sed 's/>//' \
	> "${tmpdir}"/PhageContigList.tsv

# Cut down the relative abundance table to only
# those samples and contigs from the bacteria or
# phage sets.

echo Parsing bactieral abundance table...
Rscript ./bin/ApplySepAbund.R \
	--abundance ${abundancetable} \
	--samplelist "${tmpdir}"/BacteriaSampleList.tsv \
	--contiglist "${tmpdir}"/BacteriaContigList.tsv \
	--output ${bacterialabundout}

echo Parsing phage abundance table...
Rscript ./bin/ApplySepAbund.R \
	--abundance ${abundancetable} \
	--samplelist "${tmpdir}"/PhageSampleList.tsv \
	--contiglist "${tmpdir}"/PhageContigList.tsv \
	--output ${phageabundout}

echo Removing tmp directory...
rm -r ${tmpdir}
