#! /bin/bash
# RunQualityControl.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N RunQualityControl
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
export Output='QualityControl'

export FastqFiles=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/PublishedViromeDatasets/raw

# Dependencies
export fastx=/home/ghannig/bin/fastq_quality_trimmer

echo Creating output directory...
cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################
# Some of these look simple, but this is an easy way to ensure the parameters are standardized
# across multiple calls of all subroutines.

# Just a note. I am going to avoid using cutadapt and deconseq here since the sequences
# were already processed in their original study. Here I am just going to trim the fat.

runFastx () {
	${fastx} -t 33 -Q 33 -l 75 -z -i "${1}" -o "${2}" || exit
	rm "${1}"
}

export -f runFastx

############
# Run Data #
############

for file in $(ls ${FastqFiles}); do
	echo Quality Trimming...
	echo File is ${file}
	runFastx \
			${FastqFiles}/${file} \
			./${Output}/${file}
done
