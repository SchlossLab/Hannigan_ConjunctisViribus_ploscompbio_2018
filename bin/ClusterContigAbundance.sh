#! /bin/bash
# ClusterContigAbundance.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export ClusterPhage=$1
export ClusterBacteria=$2
export AbundPhage=$3
export AbundBacteria=$4
export PhageCollapseOutput=$5
export BacteriaCollapseOutput=$6

################
# Run Analysis #
################
# Yeah I know I can loop this
# Make output directory
mkdir ./data/${OutputName}

# Format cluster files
sed 's/\,/\t/' ${ClusterPhage} \
	| sed 's/\t/\tPhage_/' \
	> ./tmpPhageClusters.tsv

sed 's/\,/\t/' ${ClusterBacteria} \
	| sed 's/\t/\tBacteria_/' \
	> ./tmpBacteriaClusters.tsv

awk -F "\t" 'FNR==NR { a[$1] = $2; next } {print a[$1]"\t"$2"\t"$3}' \
	./tmpPhageClusters.tsv \
	${AbundPhage} \
	> ./tmpPhageAbund.tsv

awk -F "\t" 'FNR==NR { a[$1] = $2; next } {print a[$1]"\t"$2"\t"$3}' \
	./tmpBacteriaClusters.tsv \
	${AbundBacteria} \
	> ./tmpBacteriaAbund.tsv

Rscript ./bin/CollapseRelativeAbundance.R \
	-i ./tmpPhageAbund.tsv \
	-o ${PhageCollapseOutput}

Rscript ./bin/CollapseRelativeAbundance.R \
	-i ./tmpBacteriaAbund.tsv \
	-o ${BacteriaCollapseOutput}

# Clean up the place
rm ./tmpPhageClusters.tsv
rm ./tmpBacteriaClusters.tsv
rm ./tmpPhageAbund.tsv
rm ./tmpBacteriaAbund.tsv
