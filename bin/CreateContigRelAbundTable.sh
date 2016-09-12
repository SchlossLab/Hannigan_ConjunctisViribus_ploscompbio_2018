#! /bin/bash
# CreateContigRelAbundTable.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N RunPhageBacteriaModel
#PBS -q first
#PBS -l nodes=1:ppn=1,mem=40gb
#PBS -l walltime=600:00:00
#PBS -j oe
#PBS -V
#PBS -A schloss_lab

#######################
# Set the Environment #
#######################

export BinPath=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/
export GitBin=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/pakbin/
export ProjectBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/

export ContigsFile=$1
# Directory for fasta sequences to align to contigs
export FastaSequences=$2
export MasterOutput=$3
export Output='data/tmpbowtie'

mkdir ./${Output}

###################
# Set Subroutines #
###################
GetHits () {
	# 1 = Input Orfs
	# 2 = Bowtie Reference

	mkdir ./${Output}/bowtieReference

	bowtie2 \
		-x ${2} \
		-q ${1} \
		-S ${1}-bowtie.sam \
		-p 32 \
		-L 25 \
		-N 1

	# Quantify alignment hits
	perl \
		${ProjectBin}calculate_abundance_from_sam.pl \
			${1}-bowtie.sam \
			${1}-bowtie.tsv
}

# Export the subroutines
export -f GetHits

#############################
# Contig Relative Abundance #
#############################

echo Getting contig relative abundance table...

rm ./${Output}/ContigRelAbundForNetwork.tsv

# Build bowtie reference
bowtie2-build \
	-q ${ContigsFile} \
	./${Output}/bowtieReference/bowtieReference

for file in $(ls ${FastaSequences}/*_2.fastq | sed "s/.*\///g"); do
	sampleid=$(echo ${file} | sed 's/_2.fastq//')
	echo Sample ID is ${sampleid}

	GetHits \
		${FastaSequences}/${file} \
		./${Output}/bowtieReference/bowtieReference

	# Remove the header
	sed -e "1d" ${FastaSequences}/${file}-bowtie.tsv > ${FastaSequences}/${file}-noheader

	awk -v name=${sampleid} '{ print $0"\t"name }' ${FastaSequences}/${file}-noheader >> ${MasterOutput}
	rm ${FastaSequences}/${file}-noheader
done




