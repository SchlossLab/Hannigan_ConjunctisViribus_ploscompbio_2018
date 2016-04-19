#!/bin/bash
# PrepareProtClusters.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Variables #
#################

# Paths
export WorkingDirectory=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='PrepareProtClusters'
export BinPath=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/bin/
export BigBin=/scratch/pschloss_flux/ghannig/bin/

# Files
export PhageDat=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/phageSVA.dat

###########
# Set Env #
###########

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

GetGeneFasta () {
	# 1 = Name
	# 2 = Input dat

	perl ${BinPath}dat2fasta.pl \
		-d "${2}" \
		-f ./${Output}/"${1}"Prot.fa \
		-p \
		-g
}

ClusterProteins () {
	# 1 = Name
	# 2 = Input Fasta

	# The 0.9 similarity threshold is default but
	# I am still specifying here.
	${BigBin}cd-hit-v4.6.5-2016-0304/cd-hit \
		-i "${2}" \
		-o ./${Output}/"${1}"Clustered \
		-c 0.9 \
		-M 64000 \
		-T 8
}

export -f GetGeneFasta
export -f ClusterProteins

################
# Run Analysis #
################

GetGeneFasta \
	"Phage" \
	${PhageDat}

ClusterProteins \
	"Phage" \
	./${Output}/PhageProt.fa
