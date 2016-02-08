# DownloadPublishedData.sh
# Geoffrey Hannigan
# Pat Schloss Laboratory
# University of Michigan

# Set the variables to be used in this script
export WorkingDirectory=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data
export Output='DownloadedSRA'

export StudyDat=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/ViromeStudyAcc.dat

# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

ParseStudyDat () {
	# 1 = Dat file
	# 2 = Output list file name

	egrep '^SR ' ${1} \
		| sed 's/^SR //' \
		> ${2}
}

DownloadSRA () {
	# 1 = Acc ID list
	mkdir ./${Output}/FastqFilesFromSra

	while read line; do
		echo Accession number is $line...
		fileType=${line:0:3}
		shortLine=${line:0:6}
		echo File type is $fileType...
		echo Short accession number is $shortLine...
		wget ftp://ftp-trace.ncbi.nih.gov/sra/sra-instant/reads/ByRun/sra/${fileType}/${shortLine}/${line}/${line}.sra ./${Output}/FastqFilesFromSra/
		#fastq-dump ${line} --outdir ./${Output}/FastqFilesFromSra
	done < ${1}
}

export -f ParseStudyDat
export -f DownloadSRA

ParseStudyDat \
	${StudyDat} \
	./${Output}/tmpList.tsv

DownloadSRA \
	./${Output}/tmpList.tsv

# Remove the tmp file
rm ./${Output}/tmpList.tsv
