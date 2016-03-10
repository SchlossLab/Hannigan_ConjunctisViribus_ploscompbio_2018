# GetMicrobeOrfs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N GetMicrobeOrfs
#PBS -A pschloss_flux
#PBS -q flux
#PBS -l qos=flux
#PBS -l procs=1:ppn=24,mem=126GB
#PBS -l walltime=500:00:00
#PBS -j oe
#PBS -V

# Set the variables to be used in this script
export WorkingDirectory=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='OrfInteractionsDiamond'

export PhageGenomes=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/phageSVAnospace.fa
export BacteriaGenomes=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/bacteriaSVAnospace.fa
export InteractionReference=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/PhageInteractionReference.tsv

export SwissProt=/mnt/EXT/Schloss-data/reference/uniprot/uniprot_sprotNoBlock.fasta
export Trembl=/mnt/EXT/Schloss-data/reference/uniprot/uniprot_tremblNoBlock.fasta

export GitBin=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/
export LocalBin=/home/ghannig/bin/
export StudyBin=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/bin/
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

	cat ${2} ${3} > ./${Output}/TremblSwiss.fa
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
		-d ./${Output}/UniprotSubsetDatabase \
		-a ./${Output}/Phage.daa \
		-t ./
	${SchlossBin}diamond blastp \
		-q ${3} \
		-d ./${Output}/UniprotSubsetDatabase \
		-a ./${Output}/Bacteria.daa \
		-t ./

	${SchlossBin}diamond view \
		-a ./${Output}/Phage.daa \
		-o ./${Output}/PhageBlast.txt

	${SchlossBin}diamond view \
		-a ./${Output}/Bacteria.daa \
		-o ./${Output}/BacteriaBlast.txt
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
	cut -f 1,2 ${1} | sed 's/\S\+|\(\S\+\)|\S\+$/\1/' > ./${Output}/PhageBlastIdReference.tsv
	cut -f 1,2 ${2} | sed 's/\S\+|\(\S\+\)|\S\+$/\1/' > ./${Output}/BacteriaBlastIdReference.tsv

	# Convert bacterial file to reference
	awk \
		'NR == FNR {a[$2] = $1; next} $1 in a { print $1"\t"$2"\t"a[$1] }' \
		./${Output}/PhageBlastIdReference.tsv \
		./${Output}/TotalInteractionRef.tsv \
		> ./${Output}/tmpMerge.tsv

	awk \
		'NR == FNR {a[$2] = $1; next} $2 in a { print $1"\t"$2"\t"$3"\t"a[$2] }' \
		./${Output}/BacteriaBlastIdReference.tsv \
		./${Output}/tmpMerge.tsv \
		| cut -f 3,4 \
		> ./${Output}/InteractiveIds.tsv

	# This output can be used for input into perl script for adding
	# to the graph database.
}

export -f PredictOrfs
export -f SubsetUniprot
export -f GetOrfUniprotHits
export -f OrfInteractionPairs


# PredictOrfs \
# 	${PhageGenomes} \
# 	PhageGenomeOrfs.fa

# PredictOrfs \
# 	${BacteriaGenomes} \
# 	BacteriaGenomeOrfs.fa

SubsetUniprot \
	${InteractionReference} \
	${SwissProt} \
	${Trembl}

GetOrfUniprotHits \
	./${Output}/TremblSwiss.fa \
	/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/PhageGenomeOrfs.fa \
	/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/BacteriaGenomeOrfs.fa

OrfInteractionPairs \
	./${Output}/PhageBlast.txt \
	./${Output}/BacteriaBlast.txt \
	./${Output}/ParsedInteractionRef.tsv

