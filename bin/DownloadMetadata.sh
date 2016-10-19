#! /bin/bash
# DownloadMetadata.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export Output='PublishedDatasets'

export SequenceHoldingFile=$1
# And this because the download for this is messed up and
# I have to do it by hand.
export ByHandFile=./data/PublishedDatasets/raw_metadata/Sra-ERP008725.txt

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

# Replace it
rm ./data/${Output}/Sra-ERP008725.txt
sed 's/SRA_Study_s/SRAStudy/' ${ByHandFile} \
	| sed 's/Run_s/Run/' \
	| sed 's/LibraryLayout_s/LibraryLayout/' \
	| sed 's/Platform_s/Platform/' \
	| sed 's/Sample_Name_s/SampleName/' \
	> ./data/${Output}/Sra-ERP008725.txt
