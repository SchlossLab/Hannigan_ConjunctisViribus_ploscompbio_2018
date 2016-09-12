#! /bin/bash
# RunPhageBacteriaModel.sh
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

export WorkingDirectory=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data
export Output='RunPhageBacteriaModel'
export BinPath=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/
export GitBin=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/pakbin/
export ProjectBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/

export PhageGenomeRef=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/AssembledContigs/FinalContigs/TotalContigs.fa
export BacteriaGenomeRef=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/ValidationSet/ValidationBacteriaNoBlockNoSpace.fa
export FastaSequences=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/AssembledContigs/fastaForAssembly

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################
GetHits () {
	# 1 = Input Orfs
	# 2 = Reference Orfs

	mkdir ./${Output}/bowtieReference

	bowtie2-build \
		-f ${2} \
		./${Output}/bowtieReference/bowtieReference

	bowtie2 \
		-x ./${Output}/bowtieReference/bowtieReference \
		-f ${1} \
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

for file in $(ls ${FastaSequences}/*_merged.fa | sed "s/.*\///g"); do
	sampleid=$(echo ${file} | sed 's/_merged.fa//')
	echo Sample ID is ${sampleid}

	# GetHits \
	# 	${FastaSequences}/${file} \
	# 	${PhageGenomeRef}

	# Remove the header
	sed -e "1d" ${FastaSequences}/${file}-bowtie.tsv > ${FastaSequences}/${file}-noheader

	awk -v name=${sampleid} '{ print $0"\t"name }' ${FastaSequences}/${file}-noheader >> ./${Output}/ContigRelAbundForNetwork.tsv
	rm ${FastaSequences}/${file}-noheader
done




