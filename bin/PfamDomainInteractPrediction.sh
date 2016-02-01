# PfamDomainInteractPrediction.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Set the variables to be used in this script
export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='PfamDomainInteractions'

export PfamDatabase=/mnt/EXT/Schloss-data/reference/Pfam/Pfam-A.hmm

export MothurProg=/share/scratch/schloss/mothur/mothur

export GitBin=/home/ghannig/git/HanniganNotebook/bin/
export SeqtkPath=/home/ghannig/bin/seqtk/seqtk
export LocalBin=/home/ghannig/bin/
export hmmerBin=/mnt/EXT/Schloss-data/bin/hmmer-3.1b2-linux-intel-x86_64/binaries/

# Get the orfs that were already predicted in 'GerMicrobeOrfs.sh'
export PhageOrfs=
export BacteriaOrfs=


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
	translate-fasta ${2} > ./${Output}/PfamDomains/${1}-TanslatedOrfs.fa

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

export -f PfamDomains

PfamDomains \
	"Phage" \
	${PhageOrfs} \
	${PfamDatabase}

PfamDomains \
	"Bacteria" \
	${BacteriaOrfs} \
	${PfamDatabase}
