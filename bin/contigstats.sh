#! /bin/bash
# contigstats.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set The Environment #
#######################

julia=/mnt/EXT/Schloss-data/bin/julia-0.4.6/bin/julia
ccontigs=/mnt/EXT/Schloss-data/ghannig/ccontigs/ccontigs.jl
contigfasta=${1}
contigcounts=${2}
outcontiglength=${3}
outcontigcount=${4}
outcontigcircles=${5}
outdir=${6}

mkdir ./data/PhageContigStats

#################
# Contig Length #
#################
awk 'NR % 2 {printf $0"\t"} !(NR % 2) {print length($0)}' \
	${contigfasta} \
	> ${outcontiglength}

sed -i 's/>//' ${outcontiglength}

#################################
# Total Contig Sequencing Depth #
#################################
Rscript ./bin/CollapseContigCounts.R \
	--input ${contigcounts} \
	--out ${outcontigcount}

####################################
# Identify Likely Circular Contigs #
####################################
# ccontigs script
${julia} ${ccontigs} \
	-i ${contigfasta} \
	-o ./data/PhageContigStats/circularcontigs.tsv

awk '{ print $1"\tCircular" }' ./data/PhageContigStats/circularcontigs.tsv \
	> ${outcontigcircles}
