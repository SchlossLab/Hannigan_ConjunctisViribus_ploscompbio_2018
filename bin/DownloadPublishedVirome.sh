#! /bin/bash
# DownloadPublishedVirome.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N DownloadPublishedVirome
#PBS -A pschloss_flux
#PBS -q flux
#PBS -l qos=flux
#PBS -l nodes=1:ppn=12,mem=64GB
#PBS -l walltime=100:00:00
#PBS -j oe
#PBS -V

#######################
# Set the Environment #
#######################

export WorkingDirectory=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='PublishedViromeDatasets'

export Metadatafile=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/PublishedDatasets/SutdyInformation.tsv

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

DownloadFromSRA () {
	line="${1}"
	echo Processing SRA Accession Number "${line}"
	mkdir ./${Output}/"${line}"
	shorterLine=${line:0:3}
	shortLine=${line:0:6}
	echo Looking for ${shorterLine} with ${shortLine}
	# Recursively download the contents of the 
	wget -r -q --no-parent ftp://ftp-trace.ncbi.nih.gov/sra/sra-instant/reads/ByStudy/sra/${shorterLine}/${shortLine}/${line}/*
	mv ./ftp-trace.ncbi.nih.gov/sra/sra-instant/reads/ByStudy/sra/"${shorterLine}"/"${shortLine}"/"${line}"/*/*.sra ./${Output}/"${line}"
	rm -r ./ftp-trace.ncbi.nih.gov
}

DownloadFromMGRAST () {
	line="${1}"
	echo Processing MG-RAST Accession Number "${line}"
	mkdir ./${Output}/"${line}"
	# Download the raw information for the metagenomic run from MG-RAST
	wget -O ./${Output}/"${line}"/tmpout.txt "http://api.metagenomics.anl.gov/1/project/mgp7236?verbosity=full"
	# Pasre the raw metagenome information for indv sample IDs
	gsed 's/mgm/\nmgm/g' mgp7236.txt \
		| grep mgm \
		| grep -v http \
		| sed 's/\"\].*//' \
		> ./${Output}/"${line}"/SampleIDs.tsv
	# Get rid of the raw metagenome information now that we are done with it
	rm ./${Output}/"${line}"/tmpout.txt
	# Now loop through all of the accession numbers from the metagenome library
	while read acc; do
		echo Loading MG-RAST Sample ID is "${acc}"
		# file=050.1 means the raw input that the author meant to archive
		wget -O ./${Output}/"${line}"/"${acc}".fa "http://api.metagenomics.anl.gov/1/download/${acc}?file=050.1"
	done < ./${Output}/"${line}"/SampleIDs.tsv
	# Get rid of the sample list file
	rm ./${Output}/"${line}"/SampleIDs.tsv
}

DownloadFromMicrobe () {
	line="${1}"
	echo Processing iMicrobe Accession Number "${line}"
	mkdir ./${Output}/"${line}"
	wget ftp://ftp.imicrobe.us/projects/"${line}"/samples/*/*.fasta.gz
	mv ./*.fasta.gz ./${Output}/"${line}"
}

############################
# Run Through the Analysis #
############################

while read line; do
	# Save the sixth variable, which is the archive type (e.g. SRA, MG-RAST)
	ArchiveType=$(echo "${line}" | awk '{ print $6 }')
	# Save the seventh variable, which is the archive accession number
	AccNumber=$(echo "${line}" | awk '{ print $7 }')
	# Now download the samples based on the archive type
	if [ "${ArchiveType}" == "SRA" ]; then
		DownloadFromSRA "${AccNumber}"
	elif [ "${ArchiveType}" == "MGRAST" ]; then
		DownloadFromMGRAST "${AccNumber}"
	elif [ "${ArchiveType}" == "iMicrobe" ]; then
		DownloadFromMicrobe "${AccNumber}"
	elif [ "${ArchiveType}" == "ArchiveSystem" ]; then
		echo Skipping file header.
	else
		echo Error in parsing accession numbers!
	fi
done < ${Metadatafile}

