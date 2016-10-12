#! /bin/bash
# QcAndContigs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Variables #
#################
export ContigDirectory=$1
export CatContigOutputFileBacteria=$2
export CatContigOutputFilePhage=$3
export metadata=$4

NewContigDirectory=./data/tmpcat

# Make output directory
mkdir "${NewContigDirectory}"

for contigdir in $(ls "${ContigDirectory}" | grep _megahit); do
	echo Contig directory is "${ContigDirectory}"/"${contigdir}"
	samplename=$(echo "${contigdir}" | sed 's/.*\///g' | sed 's/_megahit//')
	echo Formatting "${contigdir}" as "${samplename}"
	cp "${ContigDirectory}"/"${contigdir}"/final.contigs.fa "${NewContigDirectory}"/"${samplename}"_contigs.fa
done

echo Merging contig files into a master file

# Make a list of the samples associated with phages and bacteria
## Bacterial list
cut -f 3,10 ${metadata} \
	| grep Bacteria \
	| awk -v path="${NewContigDirectory}/" '{ print path$1"_contigs.fa" }' \
	> "${NewContigDirectory}"/BacteriaSampleList.tsv

# Virus sample list
cut -f 3,10 ${metadata} \
	| grep VLP \
	| awk -v path="${NewContigDirectory}/" '{ print path$1"_contigs.fa" }' \
	> "${NewContigDirectory}"/PhageSampleList.tsv

# Cat together the samples specified in the sample lists
## Bacteria
xargs < "${NewContigDirectory}"/BacteriaSampleList.tsv cat > ./tmpBacteriaContigs.fa
## Phage
xargs < "${NewContigDirectory}"/PhageSampleList.tsv cat > ./tmpPhageContigs.fa

echo Removing special characters from contig names
perl -pe 's/[^A-Z^a-z^0-9^^>^\n]+/_/g' ./tmpBacteriaContigs.fa > ${CatContigOutputFileBacteria}
perl -pe 's/[^A-Z^a-z^0-9^^>^\n]+/_/g' ./tmpPhageContigs.fa > ${CatContigOutputFilePhage}

rm ./tmpBacteriaContigs.fa
rm ./tmpPhageContigs.fa

# rm -r "${NewContigDirectory}"
