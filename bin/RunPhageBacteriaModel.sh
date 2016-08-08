#! /bin/bash
# RunPhageBacteriaModel.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N RunPhageBacteriaModel
#PBS -q first
#PBS -l nodes=1:ppn=1,mem=40gb
#PBS -l walltime=600:00:00
#PBS -j oe
#PBS -V
#PBS -A schloss_lab

#######################
# Set the Environment #
#######################

export WorkingDirectory=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data
export Output='RunPhageBacteriaModel'
export BinPath=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/
export GitBin=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/pakbin/

export PhageGenomeRef=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/AssembledContigs/FinalContigs/TotalContigs.fa
export BacteriaGenomeRef=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/ValidationSet/ValidationBacteriaNoBlockNoSpace.fa

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
		"${2}"

	sed -i 's/\*//g' "${2}"
	sed -i 's/\/n//g' "${2}"
}

FormatNames () {
	# 1 = Input file with names to be formatted
	# 2 = Output file name

	# Perl here because the regex are easierls
	perl -pe 's/ENA\S+\.\d_//g' "${1}" \
		| perl -pe 's/\,_\S+//g' \
		| perl -pe 's/_complete\S+//g' \
		| perl -pe 's/_chromosome\S+//g' \
		> "${2}"
}

# Export the subroutines
export -f PredictOrfs
export -f FormatNames

######################
# Run CRISPR scripts #
######################

# Use a tmp directory
mkdir ./${Output}/tmp

echo Extracting CRISPRs...
bash ${BinPath}RunPilerCr.sh \
	${BacteriaGenomeRef} \
	./${Output}/tmp/BenchmarkCrisprs.txt \
	"/home/ghannig/bin/pilercr1.06/" \
	|| exit

echo Getting CRISPR pairs...
bash ${BinPath}GetCrisprPhagePairs.sh \
	./${Output}/tmp/BenchmarkCrisprs.txt \
	${PhageGenomeRef} \
	./${Output}/BenchmarkCrisprs.tsv \
	"/mnt/EXT/Schloss-data/bin/blast-2.2.24/bin/" \
	${GitBin} \
	${BinPath} \
	|| exit

rm ./${Output}/tmp/*

# Format the output
FormatNames \
	./${Output}/BenchmarkCrisprs.tsv \
	./${Output}/BenchmarkCrisprsFormat.tsv

#####################
# Run BLAST scripts #
#####################

echo Getting prophages by blast...
bash ${BinPath}GetProphagesByBlast.sh \
	${PhageGenomeRef} \
	${BacteriaGenomeRef} \
	./${Output}/BenchmarkProphagesBlastn.tsv \
	${WorkingDirectory} \
	"/mnt/EXT/Schloss-data/bin/blast-2.2.24/bin/" \
	|| exit

# Format the output
FormatNames \
	./${Output}/BenchmarkProphagesBlastn.tsv \
	./${Output}/BenchmarkProphagesBlastnFormat.tsv

FormatNames \
	./${Output}/BenchmarkProphagesTblastx.tsv \
	./${Output}/BenchmarkProphagesTblastxFormat.tsv

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

######################
# Run BLASTx scripts #
######################
echo Getting gene matches by blastx...

bash ${BinPath}GetPairsByBlastx.sh \
	./${Output}/PhageReferenceOrfs.fa \
	./${Output}/BacteriaReferenceOrfs.fa \
	./${Output}/MatchesByBlastx.tsv \
	${WorkingDirectory} \
	"/mnt/EXT/Schloss-data/bin/" \
	|| exit

# Format the output
FormatNames \
	./${Output}/MatchesByBlastx.tsv \
	./${Output}/MatchesByBlastxFormat.tsv

# Format to get the right columns in the right order
awk '{ print $2"\t"$1"\t"$12 }' \
	./${Output}/MatchesByBlastxFormat.tsv \
	> MatchesByBlastxFormatOrder.tsv

####################
# Run Pfam scripts #
####################

echo Getting PFAM interactions...

bash ${BinPath}PfamDomainInteractPrediction.sh \
	./${Output}/PhageReferenceOrfs.fa \
	./${Output}/BacteriaReferenceOrfs.fa \
	./${Output}/PfamInteractions.tsv \
	"/mnt/EXT/Schloss-data/bin/" \
	"/home/ghannig/Pfam/" \
	|| exit

# Format the output
FormatNames \
	./${Output}/PfamInteractions.tsv \
	./${Output}/PfamInteractionsFormat.tsv

# Format the output order and score sum
awk '{ print $1"\t"$3"\t"($2 + $4) }' \
	./${Output}/PfamInteractionsFormat.tsv \
	> ./${Output}/PfamInteractionsFormatScored.tsv 
