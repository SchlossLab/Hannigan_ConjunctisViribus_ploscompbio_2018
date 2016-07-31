#! /bin/bash
# OperationalProteinFamilies.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N OperationalProteinFamilies
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
export ProjectBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin
export Output='OPFs'

export FastaFiles=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/AssembledContigs/ContigOrfs

export fastxfq2fa=/home/ghannig/bin/idba-1.1.1/bin/fq2fa
export idba=/home/ghannig/bin/idba-1.1.1/bin/idba_ud
export SchlossBin=/mnt/EXT/Schloss-data/bin/
export LocalBin=/home/ghannig/bin/
export RemoveBlock=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/pakbin/remove_block_fasta_format.pl

# Set MMseqs variables
export MMDIR=$(/home/ghannig/bin/mmseqs2)
export PATH=$MMDIR/bin:$PATH

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

GetProteinHits () {
	# 1 = Input Orfs
	# 2 = Reference Orfs
	# 3 = Output File

	# Create diamond database
	echo Creating Diamond Database
	${SchlossBin}diamond makedb \
		--in "${2}" \
		-d ./${Output}/DiamondReference

	# Use blast to get hits of ORFs to Uniprot genes
	${SchlossBin}diamond blastp \
		-q "${1}" \
		-d ./${Output}/DiamondReference \
		-a ./${Output}/Blastx.daa \
		-t ./

	${SchlossBin}diamond view \
		-a ./${Output}/Blastx.daa \
		-o ./${Output}/OpfBlastResults.blast
}

EstablishOpfs () {
	# 1 = Open Reading Frame fasta

	cd ./${Output}

	# Create database
	mmseqs createdb ./TotalOrfsNoBlock.fa DB

	mkdir ./tmp
    mmseqs clusteringworkflow DB clu tmp

    # Convert to fasta
    mmseqs addsequences clu DB clu_seq
    mmseqs createfasta DB DB clu_seq clu_seq.fasta
}

export -f GetProteinHits
export -f EstablishOpfs

################
# Run Analysis #
################

# cat ${FastaFiles}/* | sed 's/\*//g' > ./${Output}/TotalOrfs.fa

# # Remove block
# perl ${RemoveBlock} ./${Output}/TotalOrfs.fa ./${Output}/TotalOrfsNoBlock.fa

# sed -i 's/\/n//g' ./${Output}/TotalOrfsNoBlock.fa

EstablishOpfs
