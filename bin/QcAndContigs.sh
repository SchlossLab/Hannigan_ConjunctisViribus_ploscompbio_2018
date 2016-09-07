#! /bin/bash
# QcAndContigs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Variables #
#################
export SampleID=${1}
export SampleDirectory=${2}
export Metadata=${3}
export Output=${4}

export fastx=/home/ghannig/bin/fastq_quality_trimmer
export megahitvar=/mnt/EXT/Schloss-data/bin/megahit/megahit

###################
# Set Subroutines #
###################
runFastx () {
	echo Running fastx with "${1}"
	# Holding the data to a high standard
	${fastx} -t 33 -Q 33 -l 75 -i "${1}" -o "${2}" || exit
	rm "${1}"
}

PairedAssembleContigs () {
	python ${megahitvar} \
		--min-contig-len 2500 \
		--k-min 21 \
		--k-max 101\
		--k-step 20 \
		-t 16 \
		-1 "${1}" \
		-2 "${2}" \
		-o ${3}
}

SingleAssembleContigs () {
	python ${megahitvar} \
		--min-contig-len 2500 \
		--k-min 21 \
		--k-max 101\
		--k-step 20 \
		-t 16 \
		-r "${1}" \
		-o ${2}
}

export -f runFastx
export -f PairedAssembleContigs
export -f SingleAssembleContigs

################
# Run Analysis #
################
mkdir ./data/${Output}
rm ./data/${Output}/fastxoutput1.fq
rm ./data/${Output}/fastxoutput2.fq

# Tread carefully, these column locations are hard coded.
# Diverge not from the format, lest there be wailing and grinding of teeth.
PAIREDVAR=$(awk -v sampleid="${SampleID}" ' $3 == sampleid { print $4 } ' ${Metadata})
PLATFORM=$(awk -v sampleid="${SampleID}" ' $3 == sampleid { print $5 } ' ${Metadata})

mkdir ./data/${Output}/raw

if [[ PAIREDVAR == "PAIRED" ]]; then
	# Set correct permissions
	chmod 777 ${SampleDirectory}*/${SampleID}*.sra

	# Clean before running
	rm -r ./data/${Output}/${SampleID}

	# Unzip the files first
	ls ${SampleDirectory}*/${SampleID}*.gz | xargs -I {} --max-procs=16 sh -c '
		gunzip {}
	'
	ls ${SampleDirectory}*/${SampleID}*.sra | xargs -I {} --max-procs=16 sh -c '
		echo Processing file {}...
			fastq-dump --split-3 {} --outdir ./data/${Output}/raw
			gzip {}
	'
	runFastx \
		./data/${Output}/raw/*R1* \
		./data/${Output}/fastxoutput1.fq
	runFastx \
		./data/${Output}/raw/*R2* \
		./data/${Output}/fastxoutput2.fq
	PairedAssembleContigs \
		./data/${Output}/fastxoutput1.fq \
		./data/${Output}/fastxoutput2.fq \
		./data/${Output}/${SampleID}
else
	# Unzip the files first
	ls ${SampleDirectory}*/${SampleID}*.gz | xargs -I {} --max-procs=16 sh -c '
		gunzip {}
	'

	# Clean before running
	rm -r ./data/${Output}/${SampleID}

	# Set correct permissions
	chmod 777 ${SampleDirectory}*/${SampleID}*.sra

	ls ${SampleDirectory}*/${SampleID}*.sra | xargs -I {} --max-procs=16 sh -c '
		echo Processing file {}...
			fastq-dump --split-3 {} --outdir ./data/${Output}/raw
			gzip {}
	'
	runFastx \
		./data/${Output}/raw/* \
		./data/${Output}/fastxoutput1.fq
	PairedAssembleContigs \
		./data/${Output}/fastxoutput1.fq \
		./data/${Output}/${SampleID}
fi
