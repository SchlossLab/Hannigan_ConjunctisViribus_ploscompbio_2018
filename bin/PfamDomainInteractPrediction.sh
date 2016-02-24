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
export PhageOrfs=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/PhageGenomeOrfs.fa
export BacteriaOrfs=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/BacteriaGenomeOrfs.fa


# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

PfamDomains () {
	# 1 = Taxa Name
	# 2 = ORF Fasta (nucleotide)
	# 3 = Reference Database (pfam)

	# Make output directory and tmp
	mkdir ./${Output}/PfamDomains
	mkdir ./${Output}/tmp

	# Remove stop codon stars from fasta
	sed 's/\*$//' ${2} \
	| sed 's/ /_/g' \
	> ./${Output}/PfamDomains/${1}-TanslatedOrfs.fa

	# Split files to run faster
	split \
		--lines=1000 \
		-a 5 \
		./${Output}/PfamDomains/${1}-TanslatedOrfs.fa \
		./${Output}/tmp/tmpPfam-

	# Perform HMM alignment against pfam HMMER database
	ls ./${Output}/tmp/* | xargs -I {} --max-procs=16 ${hmmerBin}hmmscan --cpu 8 --notextw --cut_ga -o {}.log --domtblout {}.hmmscan ${3} {}

	# Put together the files
	cat ./${Output}/tmp/*.hmmscan > ./${Output}/PfamDomains/${1}-PfamDomains.hmmscan

	# Remove the tmp directory
	rm -r ./${Output}/tmp
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
		| sed 's/_[0-9]*_\#_.*//g' \
		> ./${Output}/PfamDomains/PhagePfamAcc.tsv

	grep -v '^\#' ${2}  \
		| sed 's/ \+/\t/g' \
		| cut -f 2,4 \
		| sed 's/\..\+\t/\t/' \
		| sed 's/_[0-9]*_\#_.*//g' \
		> ./${Output}/PfamDomains/BacteriaPfamAcc.tsv

	# Convert bacterial file to reference
	awk \
		'NR == FNR {a[$1] = $2; next} $1 in a { print $1"\t"$2"\t"a[$1] }' \
		./${Output}/TotalInteractionRef.tsv \
		./${Output}/PfamDomains/PhagePfamAcc.tsv \
		> ./${Output}/PfamDomains/tmpMerge.tsv

	awk \
		'NR == FNR {a[$1] = $2; next} $3 in a { print $1"\t"$2"\t"$3"\t"a[$3] }' \
		./${Output}/PfamDomains/BacteriaPfamAcc.tsv \
		./${Output}/PfamDomains/tmpMerge.tsv \
		> ./${Output}/InteractiveIds.tsv

	# This output can be used for input into perl script for adding
	# to the graph database.
}

export -f PfamDomains
export -f OrfInteractionPairs

PfamDomains \
	"Phage" \
	${PhageOrfs} \
	${PfamDatabase}

PfamDomains \
	"Bacteria" \
	${BacteriaOrfs} \
	${PfamDatabase}

OrfInteractionPairs \
	./${Output}/PfamDomains/Phage-PfamDomains.hmmscan \
	./${Output}/PfamDomains/Bacteria-PfamDomains.hmmscan \
	${InteractionReference}
