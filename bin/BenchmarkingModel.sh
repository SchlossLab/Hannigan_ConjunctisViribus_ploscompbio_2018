#! /bin/bash
# BenchmarkingModel.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N PfamDomainInteractPrediction
#PBS -A pschloss_flux
#PBS -q flux
#PBS -l qos=flux
#PBS -l nodes=1:ppn=1,mem=2GB
#PBS -l walltime=100:00:00
#PBS -j oe
#PBS -V

#######################
# Set the Environment #
#######################

export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='BenchmarkingSet'
export BinPath=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/bin/
export GitBin=/scratch/pschloss_flux/ghannig/git/OpenMetagenomeToolkit/

export PhageGenomeRef=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet/ValidationPhageNoBlock.fa
export BacteriaGenomeRef=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet/ValidationBacteriaNoBlock.fa

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

PredictOrfs () {
	# 1 = Contig Fasta File for Prodigal
	# 2 = Output File Name

	bash ${BinPath}ProdigalWrapperLargeFiles.sh \
		"${1}" \
		./${Output}/tmp-genes.fa

    # Remove the block formatting
	perl \
	${GitBin}remove_block_fasta_format.pl \
		./${Output}/tmp-genes.fa \
		./${Output}/"${2}"
}

# Export the subroutines
export -f PredictOrfs

######################
# Run CRISPR scripts #
######################

# Use a tmp directory
mkdir ./${Output}/tmp

echo Extracting CRISPRs...
bash ${BinPath}RunPilerCr.sh \
	${BacteriaGenomeRef} \
	./${Output}/tmp/BenchmarkCrisprs.txt \
	|| exit

echo Getting CRISPR pairs...
bash ${BinPath}GetCrisprPhagePairs.sh \
	./${Output}/tmp/BenchmarkCrisprs.txt \
	${PhageGenomeRef} \
	./${Output}/BenchmarkCrisprs.tsv \
	|| exit

rm ./${Output}/tmp/*

#####################
# Run BLAST scripts #
#####################

echo Getting prophages by blast...
bash ${BinPath}GetProphagesByBlast.sh \
	${PhageGenomeRef} \
	${BacteriaGenomeRef} \
	./${Output}/BenchmarkProphages.tsv \
	${WorkingDirectory} \
	|| exit

################
# Predict ORFs #
################

echo Predicting ORFs...

PredictOrfs \
	${PhageGenomeRef} \
	./${Output}/PhageReferenceOrfs.fa \
	|| exit

PredictOrfs \
	${BacteriaGenomeRef} \
	./${Output}/BacteriaReferenceOrfs.fa \
	|| exit

####################
# Run Pfam scripts #
####################

echo Getting PFAM interactions...

bash ${BinPath}PfamDomainInteractPrediction.sh \
	./${Output}/PhageReferenceOrfs.fa \
	./${Output}/BacteriaReferenceOrfs.fa \
	|| exit
