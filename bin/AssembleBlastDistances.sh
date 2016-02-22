# AssembleBlastDistances.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan
# NOTE: Use this script to get the blast similarities
# between phages and bacteria.

#######################
# Set the Environment #
#######################
export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='BlastDistance'

export Vsearch=/mnt/EXT/Schloss-data/bin/vsearch-1.9.10-linux-x86_64/bin/vsearch

export PhageGenomes=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/phageSVAnospace.fa

# Set working dir
cd ${WorkingDirectory}
mkdir ./${Output}

###########################
# Get Blast Dissimilarity #
###########################
BlastSeqs () {
	# 1 = Sample Name
	# 2 = Input Fasta

	makeblastdb \
		-dbtype nucl \
		-in ${2} \
		-out ./${Output}/${1}-database

	blastn \
    	-query ${2} \
    	-out ./${Output}/${1}-BlastResults.tsv \
    	-db ./${Output}/${1}-database \
    	-outfmt 6 \
    	-evalue 100
}

export -f BlastSeqs

BlastSeqs \
	"PhageGenomes" \
	${PhageGenomes}
