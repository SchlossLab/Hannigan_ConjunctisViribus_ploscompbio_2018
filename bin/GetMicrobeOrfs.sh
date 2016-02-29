#!/bin/sh
# GetMicrobeOrfs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N GetMicrobeOrfs
#PBS -q first

#PBS -l nodes=1:ppn=4,mem=40gb
#PBS -l walltime=500:00:00
#PBS -l cput=2000:00:00
#PBS -j oe
#PBS -V
#PBS -A schloss_lab

# Set the variables to be used in this script
export WorkingDirectory=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data
export Output='OrfInteractionsDiamond'

export MothurProg=/share/scratch/schloss/mothur/mothur

export PhageGenomes=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/phageSVAnospace.fa
export BacteriaGenomes=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/bacteriaSVAnospace.fa
export InteractionReference=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/PhageInteractionReference.tsv

export SwissProt=/mnt/EXT/Schloss-data/reference/uniprot/uniprot_sprotNoBlock.fasta
export Trembl=/mnt/EXT/Schloss-data/reference/uniprot/uniprot_tremblNoBlock.fasta

export GitBin=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/
export SeqtkPath=/home/ghannig/bin/seqtk/seqtk
export LocalBin=/home/ghannig/bin/
export StudyBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/
export SchlossBin=/mnt/EXT/Schloss-data/bin/

# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

PredictOrfs () {
	# 1 = Contig Fasta File for Prodigal
	# 2 = Output File Name

	bash ${StudyBin}ProdigalWrapperLargeFiles.sh \
		${1} \
		./${Output}/tmp-genes.fa

    # Remove the block formatting
	perl \
	${GitBin}remove_block_fasta_format.pl \
		./${Output}/tmp-genes.fa \
		./${Output}/${2}

	# # Remove the tmp file
	# rm ./${Output}/tmp*.fa
}

SubsetUniprot () {
	# 1 = Interaction Reference File
	# 2 = SwissProt Database No Block
	# 3 = Trembl Database No Block

	# Note that database should cannot be in block format
	# Create a list of the accession numbers
	cut -f 1,2 ${1} \
		| grep -v "interactor" \
		| sed 's/uniprotkb\://g' \
		> ./${Output}/ParsedInteractionRef.tsv

	# Collapse that list to single column of unique IDs
	sed 's/\t/\n/' ./${Output}/ParsedInteractionRef.tsv \
		| sort \
		| uniq \
		> ./${Output}/UniqueInteractionRef.tsv

	# Use this list to subset the Uniprot database
	perl ${GitBin}FilterFasta.pl \
		-f ${2} \
		-l ./${Output}/UniqueInteractionRef.tsv \
		-o ./${Output}/SwissProtSubset.fa
	perl ${GitBin}FilterFasta.pl \
		-f ${3} \
		-l ./${Output}/UniqueInteractionRef.tsv \
		-o ./${Output}/TremblProtSubset.fa
}

GetOrfUniprotHits () {
	# 1 = UniprotFasta
	# 2 = Phage Orfs
	# 3 = Bacteria Orfs

	# Create diamond database
	${SchlossBin}diamond makedb \
		--in ${1} \
		-d ./${Output}/UniprotSubsetDatabase

	# Use blast to get hits of ORFs to Uniprot genes
	${SchlossBin}diamond blastp \
		-q ${2} \
		-o ${2}.blast \
		-d ./${Output}/UniprotSubsetDatabase \
		-a ${2}.daa \
		-f tab
	${SchlossBin}diamond blastp \
		-q ${3} \
		-o ${3}.blast \
		-d ./${Output}/UniprotSubsetDatabase \
		-a ${2}.daa \
		-f tab
}

OrfInteractionPairs () {
	# 1 = Phage Blast Results
	# 2 = Bacterial Blast Results
	# 3 = Interaction Reference

	# Reverse the interaction reference for awk
	awk \
		'{ print $2"\t"$1 }' \
		${3} \
		> ${3}.inverse

	cat \
		${3} \
		${3}.inverse \
		> ./${Output}/TotalInteractionRef.tsv

	# Get only the ORF IDs and corresponding interactions
	# Column 1 is the ORF ID, two is Uniprot ID
	cut -f 1,2 ${1} > ./${Output}/PhageBlastIdReference.tsv
	cut -f 1,2 ${2} > ./${Output}/BacteriaBlastIdReference.tsv

	# Convert bacterial file to reference
	awk \
		'NR == FNR {a[$1] = $2; next} { print $1"\t"$2"\t"a[$1] }' \
		./${Output}/PhageBlastIdReference.tsv \
		./${Output}/TotalInteractionRef.tsv \
		> ./${Output}/tmpMerge.tsv

	awk \
		'NR == FNR {a[$2] = $1; next} { print $1"\t"$2"\t"$3"\t"a[$3] }' \
		./${Output}/BacteriaBlastIdReference.tsv \
		./${Output}/tmpMerge.tsv \
		| cut -f 1,4 \
		> ./${Output}/InteractiveIds.tsv

	# This output can be used for input into perl script for adding
	# to the graph database.
}

export -f PredictOrfs
export -f SubsetUniprot
export -f GetOrfUniprotHits
export -f OrfInteractionPairs


PredictOrfs \
	${PhageGenomes} \
	PhageGenomeOrfs.fa

PredictOrfs \
	${BacteriaGenomes} \
	BacteriaGenomeOrfs.fa

SubsetUniprot \
	${InteractionReference} \
	${SwissProt} \
	${Trembl}

GetOrfUniprotHits \
	./${Output}/SwissProtSubset.fa \
	/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/PhageGenomeOrfs.fa \
	/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/BacteriaGenomeOrfs.fa

OrfInteractionPairs \
	./${Output}/PhageGenomeOrfs.fa.blast \
	./${Output}/BacteriaGenomeOrfs.fa.blast \
	./${Output}/ParsedInteractionRef.tsv


echo "qsub working directory absolute is"
echo $PBS_O_WORKDIR
exit
