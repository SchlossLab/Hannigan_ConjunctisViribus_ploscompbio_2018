#! /bin/bash
# QcAndContigs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Variables #
#################
usage() { echo -e "Usage: This is the standardized Grice Lab QIIME workflow, with the following options: 
    [-a] First sequencing file.
    [-b] Second sequencing file (only for paired end).
    [-o] Output file."; exit 1;}

while getopts ":ha:b:o:" option; do
    case "$option" in
        h) usage ;;
        a) ONE="$OPTARG";;
        b) TWO="$OPTARG";;
        o) OUTPUT="$OPTARG";;
        :)  echo "Error: -$OPTARG requires an argument" ; exit 1;;
        ?)  echo "Error: unknown option -$OPTARG" ; exit 1;;
    esac
done

if [[ -z $ONE ]]; then
    echo "ERROR: Sequencing file is missing!"; exit 1;
elif [[ -z $TWO ]]; then
    echo "Cool, looks like some paired end data!";
elif [[ -z $OUTPUT ]]; then
    echo "ERROR: Output file name was not defined!"; exit 1;
fi

export Output='tmp'

export fastx=/home/ghannig/bin/fastq_quality_trimmer

###################
# Set Subroutines #
###################

# CONVERT FROM SRA TO FATSQ

runFastx () {
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
		-o "${3}"
}

SingleAssembleContigs () {
	python ${megahitvar} \
		--min-contig-len 2500 \
		--k-min 21 \
		--k-max 99\
		--k-step 20 \
		-t 16 \
		-r "${1}" \
		-o "${2}"
}



export -f runFastx

################
# Run Analysis #
################
mkdir ./${Output}
rm ./${Output}/fastxoutput1.fq
rm ./${Output}/fastxoutput2.fq
runFastx \
	${1} \
	./${Output}/fastxoutput.fq

if [[ -z $TWO ]]; then
	runFastx \
		${1} \
		./${Output}/fastxoutput1.fq
	runFastx \
		${2} \
		./${Output}/fastxoutput2.fq
	PairedAssembleContigs \
		./${Output}/fastxoutput1.fq \
		./${Output}/fastxoutput2.fq \
		${3}
	rm ./${Output}/fastxoutput1.fq
	rm ./${Output}/fastxoutput2.fq
else
	runFastx \
		${1} \
		./${Output}/fastxoutput1.fq
	PairedAssembleContigs \
		./${Output}/fastxoutput1.fq \
		${3}
	rm ./${Output}/fastxoutput1.fq
fi

rm -r ./${Output}

