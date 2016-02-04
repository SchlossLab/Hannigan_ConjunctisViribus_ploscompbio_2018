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

	# Translate the sequences using default axiom script
	perl ${MicroToolkit}TranslateFasta.pl \
		-f ${2} \
		-o ./${Output}/PfamDomains/${1}-TanslatedOrfs.fa

	# Perform HMM alignment against pfam HMMER database
	${hmmerBin}hmmscan \
		--notextw \
		--cut_ga \
		--domtblout ./${Output}/PfamDomains/${1}-PfamDomains.hmmscan \
		${3} \
		./${Output}/PfamDomains/${1}-TanslatedOrfs.fa

	# Format the data so it is easier to deal with in R analysis
	# The cut by character count works because it is space delimited
	# With the final column starting at character 181.
	grep -v '#' ./${Output}/PfamDomains/${1}-PfamDomains.hmmscan  \
		| cut -c 1-180 \
		| sed 's/\s\+/\t/g' \
		| sort -rnk22 \
		> ./${Output}/PfamDomains/${1}-PfamDomainsFormat.tsv
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
	cut -f 2,4 ${1} \
		| sed 's/\.orf\d\+//' \
		| sed 's/\.\d\+\t/\t/' \
		> ./${Output}/PfamDomains/PhagePfamAcc.tsv

	cut -f 2,4 ${2} \
		| sed 's/\.orf\d\+//' \
		| sed 's/\.\d\+\t/\t/' \
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
		./${Output}/tmpMerge.tsv \
		| cut -f 1,4 \
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
	${PhageOrfs} \
	${PfamDatabase}

OrfInteractionPairs \
	./${Output}/PfamDomains/Phage-PfamDomainsFormat.tsv \
	./${Output}/PfamDomains/Bacteria-PfamDomainsFormat.tsv \
	${InteractionReference}
