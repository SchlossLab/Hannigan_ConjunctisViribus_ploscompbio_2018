#! /bin/bash
# QcAndContigs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Variables #
#################
export ContigDirectory=$1
export NewContigDirectory=$2

ls ${ContigDirectory}*_megahit | xargs -I {} --max-procs=1 sh -c '
	contigdir={}
	samplename=$(echo ${contigdir} | sed 's/.*\///g' | sed 's/_megahit//')
	echo Formatting ${contigdir} as ${samplename}
	cp ${contigdir}/final.contigs.fa ${NewContigDirectory}/${samplename}
'
