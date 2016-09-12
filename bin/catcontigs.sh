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

for contigdir in $(ls "${ContigDirectory}" | grep _megahit); do
	echo Contig directory is "${ContigDirectory}"/"${contigdir}"
	samplename=$(echo "${contigdir}" | sed 's/.*\///g' | sed 's/_megahit//')
	echo Formatting "${contigdir}" as "${samplename}"
	cp "${ContigDirectory}"/"${contigdir}"/final.contigs.fa "${NewContigDirectory}"/"${samplename}"_contigs.fa
done
