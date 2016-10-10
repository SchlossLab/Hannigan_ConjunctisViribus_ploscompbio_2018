#! /bin/bash
# ClusterContigAbundance.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export input=$1
export output=$2
export ContigClusters=$3
export OutputName=$4


###################
# Set Subroutines #
###################

AnnotateCollapseClusters () {
	FileToAnnotate=$1
	OutputAnnotate=$2

	awk -F "\t" 'FNR==NR { a[$1] = $2; next } {print a[$1]"\t"$2"\t"$3}' \
		./data/${OutputName}/ContClust.tsv \
		${FileToAnnotate} \
		> ./data/${OutputName}/tmpAnnotations.tsv

	Rscript ./bin/CollapseRelativeAbundance.R \
		-i ./data/${OutputName}/tmpAnnotations.tsv \
		-o ${OutputAnnotate}

	# Remove the tmp file
	rm ./data/${OutputName}/tmpAnnotations.tsv
}

export -f AnnotateCollapseClusters

################
# Run Analysis #
################
# Make output directory
mkdir ./data/${OutputName}

# Format the contig clustering table
sed 's/,/\t/' ${ContigClusters} > ./data/${OutputName}/ContClust.tsv

# Run the subroutines
# I know I know I should loop this
AnnotateCollapseClusters \
	${input} \
	${output}
