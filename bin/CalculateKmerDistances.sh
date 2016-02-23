# CalculateKmerDistances.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set the Environment #
#######################
export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='KmerDistance'

export KmerCalc=/home/ghannig/git/ViromeKmerSpectrum/bin/CalculateKmerDistances.pl

export PhageGenomes=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/phageSVAnospace.fa

# Set working dir
cd ${WorkingDirectory}
mkdir ./${Output}

######################
# Get Kmer Distances #
######################
perl ${KmerCalc} \
	-i ${PhageGenomes} \
	-t ${PhageGenomes} \
	-o ./${Output}/4merDistFormat.tsv \
	-f ./${Output}/4merDist.tsv \
	-r
