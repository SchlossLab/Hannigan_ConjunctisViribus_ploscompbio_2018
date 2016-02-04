# ProdigalWrapperLargeFiles.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan
# WARNING: This cannot take block formatted fasta files!

##############################
# Default Values and CL Args #
##############################
# Set pilerCR path
export ProdigalPath=/mnt/EXT/Schloss-data/bin/
# Maximum input file size in bytes
export MaxFileSize=25000000 #25 MB
export FastaInput=$1
export OutputName=$2
export SplitSize=20
export Remove=FALSE
# Determine file size of input file
export FileSize=$(wc -c ${FastaInput} | sed 's/ .*//')
# Specify working directory
export WorkDir=$(pwd)
echo "We are working in ${WorkDir}"

#############
# Call ORFs #
#############
# Make a tmp directory
mkdir ./tmp
# Split files if needed
if [[ "${FileSize}" -gt "${MaxFileSize}" ]]; then
	echo "Input larger than ${MaxFileSize} MB."
	# Split the file
	split \
		--lines=${SplitSize} \
		${FastaInput} \
		./tmp/tmpProdigal-
else
	echo "File is small so does not need split."
	# Copy file to tmp for ease
	cp ${FastaInput} ./tmp/
fi

# Now run pilerCR on the files
ls ./tmp/* | xargs -I {} --max-procs=128 ${ProdigalPath}prodigal -c -i {} -o {}.genes -a {}.out -p meta

# Collect the results together
cat ./tmp/*.out > ./${OutputName}

# Finally remove the tmp directories
if [[ "${Remove}" = "FALSE" ]]; then
	echo "Keeping tmp dir..."
else
	echo "Removing tmp dir..."
	rm -r ./tmp
fi

