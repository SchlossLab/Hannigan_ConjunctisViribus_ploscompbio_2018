#! /bin/bash
# BenchmarkingModel.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#######################
# Set the Environment #
#######################

export Output='BenchmarkingSet'

export PhageGenomeRef=${1}
export BacteriaGenomeRef=${2}
export CRISPRout=${3}
export ProphageOutFile=${4}
export BlastxOut=${5}
export PfamOut=${6}
export WorkingDirectory=$(pwd)

mkdir ./data/${Output}

###################
# Set Subroutines #
###################

PredictOrfs () {
	# 1 = Contig Fasta File for Prodigal
	# 2 = Output File Name

	bash ./bin/ProdigalWrapperLargeFiles.sh \
		"${1}" \
		./data/${Output}/tmp-genes.fa

    # Remove the block formatting
	perl \
	./bin/remove_block_fasta_format.pl \
		./data/${Output}/tmp-genes.fa \
		"${2}"

	sed -i 's/\*//g' "${2}"
	sed -i 's/\/n//g' "${2}"
}

FormatNames () {
	# 1 = Input file with names to be formatted
	# 2 = Output file name

	# Perl here because the regex are easier
	perl -pe 's/ENA\S+\.\d_//g' "${1}" \
		| perl -pe 's/\,_\S+//g' \
		| perl -pe 's/_complete\S+//g' \
		| perl -pe 's/_chromosome\S+//g' \
		> "${2}"
}

GetHits () {
	# 1 = Input Orfs
	# 2 = Reference Orfs

	mkdir ./data/${Output}/bowtieReference

	bowtie2-build \
		-f ${2} \
		./data/${Output}/bowtieReference/bowtieReference

	bowtie2 \
		-x ./data/${Output}/bowtieReference/bowtieReference \
		-f ${1} \
		-S ${1}-bowtie.sam \
		-p 32 \
		-L 25 \
		-N 1

	# Quantify alignment hits
	perl \
		${ProjectBin}calculate_abundance_from_sam.pl \
			${1}-bowtie.sam \
			${1}-bowtie.tsv
}

# Export the subroutines
export -f PredictOrfs
export -f FormatNames
export -f GetHits

######################
# Run CRISPR scripts #
######################

# Use a tmp directory
mkdir ./data/${Output}/tmp

echo Extracting CRISPRs...
bash ./bin/RunPilerCr.sh \
	${BacteriaGenomeRef} \
	./data/${Output}/tmp/BenchmarkCrisprs.txt \
	"/home/ghannig/bin/pilercr1.06/" \
	|| exit

echo Getting CRISPR pairs...
bash ./bin/GetCrisprPhagePairs.sh \
	./data/${Output}/tmp/BenchmarkCrisprs.txt \
	${PhageGenomeRef} \
	./data/${Output}/BenchmarkCrisprs.tsv \
	"/home/ghannig/bin/ncbi-blast-2.4.0+/bin/" \
	./bin/ \
	./bin/ \
	|| exit

rm ./data/${Output}/tmp/*

# Format the output
FormatNames \
	./data/${Output}/BenchmarkCrisprs.tsv \
	${CRISPRout}

#####################
# Run BLAST scripts #
#####################

echo Getting prophages by blast...
bash ./bin/GetProphagesByBlast.sh \
	${PhageGenomeRef} \
	${BacteriaGenomeRef} \
	./data/${Output}/BenchmarkProphagesBlastn.tsv \
	${WorkingDirectory} \
	"/home/ghannig/bin/ncbi-blast-2.4.0+/bin/" \
	|| exit

# Format the output
FormatNames \
	./data/${Output}/BenchmarkProphagesBlastn.tsv \
	./data/${Output}/BenchmarkProphagesBlastnFormat.tsv

# Flip the output
awk '{print $2"\t"$1"\t"$3}' ./data/${Output}/BenchmarkProphagesBlastnFormat.tsv \
	> ${ProphageOutFile}

################
# Predict ORFs #
################

echo Predicting ORFs...

PredictOrfs \
	${PhageGenomeRef} \
	./data/${Output}/PhageReferenceOrfs.fa \
	|| exit

PredictOrfs \
	${BacteriaGenomeRef} \
	./data/${Output}/BacteriaReferenceOrfs.fa \
	|| exit

######################
# Run BLASTx scripts #
######################
echo Getting gene matches by blastx...

bash ./bin/GetPairsByBlastx.sh \
	./data/${Output}/PhageReferenceOrfs.fa \
	./data/${Output}/BacteriaReferenceOrfs.fa \
	./data/${Output}/MatchesByBlastx.tsv \
	${WorkingDirectory} \
	"/mnt/EXT/Schloss-data/bin/" \
	|| exit

# Format the output
FormatNames \
	./data/${Output}/MatchesByBlastx.tsv \
	./data/${Output}/MatchesByBlastxFormat.tsv

# Format to get the right columns in the right order
awk '{ print $2"\t"$1"\t"$12 }' \
	./data/${Output}/MatchesByBlastxFormat.tsv \
	> ${BlastxOut}

sed -i 's/_[0-9]*$//' ${BlastxOut}

####################
# Run Pfam scripts #
####################

echo Getting PFAM interactions...

bash ./bin/PfamDomainInteractPrediction.sh \
	./data/${Output}/PhageReferenceOrfs.fa \
	./data/${Output}/BacteriaReferenceOrfs.fa \
	./data/${Output}/PfamInteractions.tsv \
	${WorkingDirectory} \
	"/mnt/EXT/Schloss-data/bin/" \
	"/home/ghannig/Pfam/" \
	|| exit

# Format the output
FormatNames \
	./data/${Output}/PfamInteractions.tsv \
	./data/${Output}/PfamInteractionsFormat.tsv

# Format the output order and score sum
awk '{ print $1"\t"$3"\t"($2 + $4) }' \
	./data/${Output}/PfamInteractionsFormat.tsv \
	> ./data/${Output}/PfamInteractionsFormatScored.tsv 

# Flip output
awk '{print $2"\t"$1"\t"$3}' ./data/${Output}/PfamInteractionsFormatScored.tsv  \
	> ${PfamOut}

sed -i 's/_[0-9]*$//' ${PfamOut}
