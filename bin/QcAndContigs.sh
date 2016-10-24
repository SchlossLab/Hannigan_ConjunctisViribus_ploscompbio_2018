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
export megahitvar=/home/ghannig/bin/megahit/megahit

###################
# Set Subroutines #
###################
runFastx () {
	echo Running fastx with "${1}"
	echo Fastx output is "${2}"
	# Holding the data to a high standard
	${fastx} -t 33 -Q 33 -l 75 -i "${1}" -o "${2}" || exit
}

PairedAssembleContigs () {
	echo Output is "${3}"
	echo First file is "${1}"
	echo Second file is "${2}"
	python ${megahitvar} \
		-1 "${1}" \
		-2 "${2}" \
		--min-contig-len 2500 \
		--k-min 21 \
		--k-max 101\
		--k-step 20 \
		-t 8 \
		-o "${3}"
}

SingleAssembleContigs () {
	echo Output is "${2}"
	python ${megahitvar} \
		-r "${1}" \
		--min-contig-len 2500 \
		--k-min 21 \
		--k-max 101\
		--k-step 20 \
		-t 8 \
		-o "${2}"
}

export -f runFastx
export -f PairedAssembleContigs
export -f SingleAssembleContigs

################
# Run Analysis #
################
mkdir -p ./data/${Output}
rm -f ./data/${Output}/fastxoutput1.fq
rm -f ./data/${Output}/fastxoutput2.fq

# Tread carefully, these column locations are hard coded.
# Diverge not from the format, lest there be wailing and grinding of teeth.
PAIREDVAR=$(awk -v sampleid="${SampleID}" ' $3 == sampleid { print $4 } ' ${Metadata})
PLATFORM=$(awk -v sampleid="${SampleID}" ' $3 == sampleid { print $5 } ' ${Metadata})

echo Paried value is ${PAIREDVAR}

mkdir -p ./data/${Output}/raw

if [[ ${PAIREDVAR} = "PAIRED" ]]; then
	echo Running paired sample...

	ls ${SampleDirectory}*/${SampleID}*.gz | xargs -I {} --max-procs=4 sh -c '
		gunzip {}
	'

	# Set correct permissions
	chmod 777 ${SampleDirectory}*/${SampleID}*.sra

	# Clean up
	rm -f -r ./data/${Output}/${SampleID}_megahit
	rm -f -r ./data/${Output}/${SampleID}

	ls ${SampleDirectory}*/${SampleID}*.sra | xargs -I {} --max-procs=4 sh -c '
		echo Processing file {}...
			fastq-dump --split-3 {} --outdir ./data/${Output}/raw
			gzip {}
	'
	runFastx \
		./data/${Output}/raw/${SampleID}*1* \
		./data/${Output}/${SampleID}fastxoutput1untrimmed.fq
	runFastx \
		./data/${Output}/raw/${SampleID}*2* \
		./data/${Output}/${SampleID}fastxoutput2untrimmed.fq

	python ./bin/get_trimmed_pairs.py \
		-f ./data/${Output}/${SampleID}fastxoutput1untrimmed.fq \
		-s ./data/${Output}/${SampleID}fastxoutput2untrimmed.fq \
		-o ./data/${Output}/${SampleID}fastxoutput1.fq \
		-t ./data/${Output}/${SampleID}fastxoutput2.fq

	# Clean up intermediate files
	rm -f ./data/${Output}/${SampleID}${SampleID}fastxoutput1untrimmed.fq
	rm -f ./data/${Output}/${SampleID}${SampleID}fastxoutput2untrimmed.fq

	PairedAssembleContigs \
		./data/${Output}/${SampleID}fastxoutput1.fq \
		./data/${Output}/${SampleID}fastxoutput2.fq \
		./data/${Output}/${SampleID}_megahit
else
	echo Running single end sample...

	# Unzip the files first
	ls ${SampleDirectory}*/${SampleID}*.gz | xargs -I {} --max-procs=4 sh -c '
		gunzip {}
	'

	# Clean before running
	rm -f -r ./data/${Output}/${SampleID}
	rm -f -r ./data/${Output}/${SampleID}_megahit

	# Set correct permissions
	chmod 777 ${SampleDirectory}*/${SampleID}*.sra

	ls ${SampleDirectory}*/${SampleID}*.sra | xargs -I {} --max-procs=4 sh -c '
		echo Processing file {}...
			fastq-dump --split-3 {} --outdir ./data/${Output}/raw
			gzip {}
	'
	runFastx \
		./data/${Output}/raw/${SampleID}* \
		./data/${Output}/${SampleID}fastxoutput.fq
	SingleAssembleContigs \
		./data/${Output}/${SampleID}fastxoutput.fq \
		./data/${Output}/${SampleID}_megahit
fi
