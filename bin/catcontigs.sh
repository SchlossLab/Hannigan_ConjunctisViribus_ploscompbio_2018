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

for contigdir in $(${ContigDirectory}*_megahit); do
	samplename=$(echo ${contigdir} | sed 's/.*\///g' | sed 's/_megahit//')
	echo Formatting ${contigdir} as ${samplename}
	cp ${contigdir}/final.contigs.fa ${NewContigDirectory}/${samplename}
done
