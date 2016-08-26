#! /bin/bash
# DownloadMetadata.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export Output='PublishedDatasets'

export SequenceHoldingFile=$1

mkdir ./data/${Output}

DownloadSraData () {
	line="${1}"
	# Download the file
	wget -O ./data/${Output}/Sra-${line}.txt "http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=${line}"
	# Convert to tab delimited
	sed -i 's/\,/\t/g' ./data/${Output}/Sra-${line}.txt
}

while read line; do
	# Save the sixth variable, which is the archive type (e.g. SRA, MG-RAST)
	ArchiveType=$(echo "${line}" | awk '{ print $6 }')
	# Save the seventh variable, which is the archive accession number
	AccNumber=$(echo "${line}" | awk '{ print $7 }')
	echo Processing ${AccNumber} in ${ArchiveType}
	# Now download the samples based on the archive type
	if [ "${ArchiveType}" == "SRA" ]; then
		DownloadSraData "${AccNumber}"
	elif [ "${ArchiveType}" == "MGRAST" ]; then
		echo MGRAST
	elif [ "${ArchiveType}" == "iMicrobe" ]; then
		echo iMicrobe
	elif [ "${ArchiveType}" == "ArchiveSystem" ]; then
		echo Skipping file header.
	else
		echo Error in parsing accession numbers!
	fi
done < ${SequenceHoldingFile}
