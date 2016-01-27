# RunPilerCr.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##############################
# Default Values and CL Args #
##############################
# Set pilerCR path
export PilerPath=~/bin/pilercr1.06/
# Maximum input file size in bytes
export MaxFileSize=500000000 #500 MB
export FastaInput=$1
export OutputName=$2
export SplitSize=250
export Remove=FALSE
# Determine file size of input file
export FileSize=$(wc -c ${FastaInput} | sed 's/ .*//')
# Specify working directory
export WorkDir=$(pwd)
echo "We are working in ${WorkDir}"

###################
# Extract CRISPRs #
###################
# Make a tmp directory
mkdir ./tmp
# Split files if needed
if [[ "${FileSize}" -gt "${MaxFileSize}" ]]; then
	echo "Input larger than ${MaxFileSize}."
	# Split the file
	split \
		--lines=${SplitSize} \
		${FastaInput} \
		./tmp/tmpPiler-
else
	echo "File is small so does not need split."
	# Copy file to tmp for ease
	cp ${FastaInput} ./tmp/
fi

# Now run pilerCR on the files
mkdir ./tmpOut
ls ./tmp/* | xargs -I {} --max-procs=32 ${PilerPath}pilercr -in {} -out ./tmpOut/${file}.txt

# Collect the results together
cat ./tmpOut/* > ./$OutputName

# Finally remove the tmp directories
if [[ "${Remove}" = "FALSE" ]]; then
	echo "Not removing tmp dir..."
else
	echo "Removing tmp dir..."
	rm -r ./tmp
	rm -r ./tmpOut
fi
