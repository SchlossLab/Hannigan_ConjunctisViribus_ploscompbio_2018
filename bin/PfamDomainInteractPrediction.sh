# PfamDomainInteractPrediction.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Set the variables to be used in this script
export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='PfamDomainInteractions'

export PfamDatabase=/mnt/EXT/Schloss-data/reference/Pfam/Pfam-A.hmm
export InteractionReference=/mnt/EXT/Schloss-data/reference/DomineInteractionDb/PfamAccInteractions.tsv

export MothurProg=/share/scratch/schloss/mothur/mothur

export GitBin=/home/ghannig/git/HanniganNotebook/bin/
export MicroToolkit=/home/ghannig/git/Microbiome_sequence_analysis_toolkit/
export SeqtkPath=/home/ghannig/bin/seqtk/seqtk
export LocalBin=/home/ghannig/bin/
export hmmerBin=/mnt/EXT/Schloss-data/bin/hmmer-3.1b2-linux-intel-x86_64/binaries/

# Get the orfs that were already predicted in 'GerMicrobeOrfs.sh'
export PhageOrfs=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/OrfInteractions/PhageGenomeOrfs.fa
export BacteriaOrfs=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/OrfInteractions/BacteriaGenomeOrfs.fa


# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

PfamDomains () {
	# 1 = Taxa Name
	# 2 = ORF Fasta (nucleotide)
	# 3 = Reference Database (pfam)

	# Make output directory
	mkdir ./${Output}/PfamDomains

	# Remove stop codon stars from fasta
	sed 's/\*$//' ${2} \
	| sed 's/ /_/g' \
	> ./${Output}/PfamDomains/${1}-TanslatedOrfs.fa

	# Perform HMM alignment against pfam HMMER database
	${hmmerBin}hmmscan \
		--notextw \
		--cut_ga \
		--domtblout ./${Output}/PfamDomains/${1}-PfamDomains.hmmscan \
		${3} \
		./${Output}/PfamDomains/${1}-TanslatedOrfs.fa
}

OrfInteractionPairs () {
	# 1 = Phage  Pfam Results
	# 2 = Bacterial  Pfam Results
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
	grep -v '^\#' ${1}  \
		| sed 's/ \+/\t/g' \
		| cut -f 2,4 \
		| sed 's/\..\+\t/\t/' \
		> ./${Output}/PfamDomains/PhagePfamAcc.tsv

	grep -v '^\#' ${2}  \
		| sed 's/ \+/\t/g' \
		| cut -f 2,4 \
		| sed 's/\..\+\t/\t/' \
		> ./${Output}/PfamDomains/BacteriaPfamAcc.tsv

	# Convert bacterial file to reference
	awk \
		'NR == FNR {a[$1] = $2; next} { print $1"\t"$2"\t"a[$1] }' \
		./${Output}/PfamDomains/PhagePfamAcc.tsv \
		./${Output}/TotalInteractionRef.tsv \
		> ./${Output}/PfamDomains/tmpMerge.tsv

	awk \
		'NR == FNR {a[$2] = $1; next} { print $1"\t"$2"\t"$3"\t"a[$3] }' \
		./${Output}/PfamDomains/BacteriaPfamAcc.tsv \
		./${Output}/PfamDomains/tmpMerge.tsv \
		| cut -f 1,4 \
		> ./${Output}/InteractiveIds.tsv

	# This output can be used for input into perl script for adding
	# to the graph database.
}

export -f PfamDomains
export -f OrfInteractionPairs

# PfamDomains \
# 	"Phage" \
# 	${PhageOrfs} \
# 	${PfamDatabase}

# PfamDomains \
# 	"Bacteria" \
# 	${BacteriaOrfs} \
# 	${PfamDatabase}

OrfInteractionPairs \
	./${Output}/PfamDomains/Phage-PfamDomains.hmmscan \
	./${Output}/PfamDomains/Bacteria-PfamDomains.hmmscan \
	${InteractionReference}
