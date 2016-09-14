#! /bin/bash
# contigstats.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set The Environment #
#######################

julia=/mnt/EXT/Schloss-data/bin/julia-0.4.6/bin/julia
ccontigs=/mnt/EXT/Schloss-data/ghannig/ccontigs
contigfasta=${1}
contigcounts=${2}

mkdir ./data/PhageContigStats

#################
# Contig Length #
#################
awk 'NR % 2 {printf $0"\t"} !(NR % 2) {print length($0)}' \
	${contigfasta} \
	> ./data/PhageContigStats/ContigLength.tsv

#################################
# Total Contig Sequencing Depth #
#################################
Rscript ./bin/CollapseContigCounts.R \
	--input ${contigcounts} \
	--out ./data/PhageContigStats/FinalContigCounts.tsv

####################################
# Identify Likely Circular Contigs #
####################################
# ccontigs script
${julia} ${ccontigs} ccontigs.jl \
	--input ${contigfasta} \
	--output ./data/PhageContigStats/circularcontigs.tsv

awk '{ print $1"\tCircular" }' ./data/PhageContigStats/circularcontigs.tsv \
	> ./data/PhageContigStats/circularcontigsFormat.tsv
