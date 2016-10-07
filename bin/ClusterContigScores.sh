#! /bin/bash
# ClusterContigScores.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export ProphageBlast=$1
export BlastxResults=$2
export PfamResults=$3
export ProphageOut=$4
export BlastxOut=$5
export PfamOut=$6
export ContigClusters=$7
export OutputName=$8


###################
# Set Subroutines #
###################

AnnotateCollapseClusters () {
	FileToAnnotate=$1
	OutputAnnotate=$2

	awk -F "\t" 'FNR==NR { a[$1] = $2; next } {print $1"\t"a[$2]"\t"$3}' \
		./data/${OutputName}/ContClust.tsv \
		${FileToAnnotate} \
		> ./data/${OutputName}/tmpAnnotations.tsv

	Rscript ./bin/CollapseGeneScores.R \
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
sed 's/,/\t/' $7 > ./data/${OutputName}/ContClust.tsv

# Run the subroutines
# I know I know I should loop this
AnnotateCollapseClusters \
	${ProphageBlast} \
	${ProphageOut}

AnnotateCollapseClusters \
	${BlastxResults} \
	${BlastxOut}

AnnotateCollapseClusters \
	${PfamResults} \
	${PfamOut}
