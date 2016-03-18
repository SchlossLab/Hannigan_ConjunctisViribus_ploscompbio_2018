# PfamDomainInteractPrediction.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N PfamDomainInteractPrediction
#PBS -A pschloss_flux
#PBS -q flux
#PBS -l qos=flux
#PBS -l nodes=1:ppn=24,mem=124GB
#PBS -l walltime=100:00:00
#PBS -j oe
#PBS -V

# Set the variables to be used in this script
export WorkingDirectory=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='PfamDomainInteractions'

export PfamDatabase=/scratch/pschloss_flux/ghannig/reference/Pfam/Pfam-A-diamond
export InteractionReference=/scratch/pschloss_flux/ghannig/reference/Pfam/PfamAccInteractions.tsv

export SchlossBin=/scratch/pschloss_flux/ghannig/bin/

# Get the orfs that were already predicted in 'GerMicrobeOrfs.sh'
export PhageOrfs=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/PhageGenomeOrfs.fa
export BacteriaOrfs=/scratch/pschloss_flux/ghannig/git/Hannigan-2016-ConjunctisViribus/data/BacteriaGenomeOrfs.fa


# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

GetPfamHits () {
	# 1 = Database
	# 2 = Phage Orfs
	# 3 = Bacteria Orfs

	# Use blast to get hits of ORFs to Uniprot genes
	${SchlossBin}diamond blastp \
		-q ${2} \
		-d ${1} \
		-a ./${Output}/Phage.daa \
		-t ./
	${SchlossBin}diamond blastp \
		-q ${3} \
		-d ${1} \
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

export -f GetPfamHits
export -f OrfInteractionPairs

GetPfamHits \
	${PfamDatabase} \
	${PhageOrfs} \
	${BacteriaOrfs}

OrfInteractionPairs \
	./${Output}/PhageBlast.txt \
	./${Output}/BacteriaBlast.txt \
	${InteractionReference}
