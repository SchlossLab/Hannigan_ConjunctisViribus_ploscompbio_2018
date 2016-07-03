#! /bin/bash
# AssembleContigs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N AssembleContigs
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
export Output='Assembled Contigs'

export FastqFiles=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/PublishedViromeDatasets/qualityTrimmed

export fastxfq2fa=/home/ghannig/bin/fastq_to_fasta

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

ConvertFq2Fa () {
	# 1 = File Name
	${fastxfq2fa} -i ${1} -o ${2}
	rm ${1}
}

export -f ConvertFq2Fa

################
# Run Analysis #
################

mkdir ./${Output}/fastaForAssembly

ls ${FastqFiles}/*_1.fastq | xargs -I {} --max-procs=16 sh -c '
	filename=$(echo {} | sed "s/.*\///g" | sed "s/_1.*//g")
	echo Processing file ${filename}...
	
	# Convert the first of the pairs
	ConvertFq2Fa \
		${FastqFiles}/${filename}_1.fastq \
		./${Output}/fastaForAssembly/${filename}_1.fa

	ConvertFq2Fa \
		${FastqFiles}/${filename}_2.fastq \
		./${Output}/fastaForAssembly/${filename}_2.fa
'
