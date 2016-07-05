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
export ProjectBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin
export Output='AssembledContigs'

export FastqFiles=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/PublishedViromeDatasets/qualityTrimmed

export fastxfq2fa=/home/ghannig/bin/idba-1.1.1/bin/fq2fa
export idba=/home/ghannig/bin/idba-1.1.1/bin/idba_ud

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

ConvertFq2Fa () {
	${fastxfq2fa} --filter --merge ${1} ${2} ${3}
	rm ${1}
	rm ${2}
}

AssembleContigs () {
	${idba} -l ${1} -o ${2} --pre_correction --num_threads 1 --min_contig 1000
}

export -f ConvertFq2Fa
export -f AssembleContigs

################
# Run Analysis #
################

# mkdir ./${Output}/fastaForAssembly
# mkdir ./${Output}/FinalContigs

# ls ${FastqFiles}/*_1.fastq | xargs -I {} --max-procs=4 sh -c '
# 	filename=$(echo {} | sed "s/.*\///g" | sed "s/_1.*//g")
# 	echo Processing file ${filename}...
	
# 	# Convert the first of the pairs
# 	ConvertFq2Fa \
# 		${FastqFiles}/${filename}_1.fastq \
# 		${FastqFiles}/${filename}_2.fastq \
# 		./${Output}/fastaForAssembly/${filename}_merged.fa

# 	# Run the assembler
# 	AssembleContigs \
# 		./${Output}/fastaForAssembly/${filename}_merged.fa \
# 		./${Output}/FinalContigs/${filename}_contigs
# '

# ls ./${Output}/FinalContigs/ | xargs -I {} --max-procs=4 sh -c '
# 	filename=$(echo {} | sed "s/.*\///g" | sed "s/_1.*//g")
# 	cp ./${Output}/FinalContigs/${filename}/contig.fa ./${Output}/FinalContigs/${filename}.fa
# 	rm -r ./${Output}/FinalContigs/${filename}
# '

mkdir ./${Output}/ContigOrfs

for file in $(ls ./${Output}/FinalContigs/); do
	${ProjectBin}/ProdigalWrapperLargeFiles.sh ./${Output}/FinalContigs/${file} ./${Output}/ContigOrfs/${file}
done
