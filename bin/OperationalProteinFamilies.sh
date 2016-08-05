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
export ProjectBin=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/
export Output='OPFs'

export FastaFiles=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/AssembledContigs/ContigOrfs
export FastaSequences=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/AssembledContigs/fastaForAssembly

export fastxfq2fa=/home/ghannig/bin/idba-1.1.1/bin/fq2fa
export idba=/home/ghannig/bin/idba-1.1.1/bin/idba_ud
export SchlossBin=/mnt/EXT/Schloss-data/bin/
export LocalBin=/home/ghannig/bin/
export RemoveBlock=/mnt/EXT/Schloss-data/ghannig/OpenMetagenomeToolkit/pakbin/remove_block_fasta_format.pl

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

GetProteinHits () {
	# 1 = Input Orfs
	# 2 = Reference Orfs

	mkdir ./${Output}/bowtieReference

	bowtie2-build \
		-f ${2} \
		./${Output}/bowtieReference/bowtieReference

	bowtie2 \
		-x ./${Output}/bowtieReference/bowtieReference \
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

EstablishOpfs () {
	# 1 = Open Reading Frame fasta

	# Set MMseqs variables
	export MMDIR=/home/ghannig/bin/mmseqs2
	export PATH=$MMDIR/bin:$PATH
	echo Path is "$PATH"

	cd ./${Output} || exit

	# Create database
	mmseqs createdb ./TotalOrfsNoBlock.fa DB

	mkdir ./tmp
    mmseqs clusteringworkflow DB clu tmp

    # Convert to fasta
    mmseqs addsequences clu DB clu_seq
    mmseqs createfasta DB DB clu_seq clu_seq.fasta

    # Back out of the directory
    cd .. || exit
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

# EstablishOpfs



# # Get together the sequences

# cat ${FastaSequences}/* | sed 's/\*//g' > ./${Output}/TotalSeqs.fa
# cat ${FastaFiles}/*.nucleotide | sed 's/\*//g' > ./${Output}/TotalOrfsNucl.fa

# # Remove block
# perl ${RemoveBlock} ./${Output}/TotalOrfsNucl.fa ./${Output}/TotalOrfsNuclNoBlock.fa

# sed -i 's/\/n//g' ./${Output}/TotalSeqs.fa

# GetProteinHits \
# 	./${Output}/TotalSeqs.fa \
# 	./${Output}/TotalOrfsNuclNoBlock.fa

# I also want to go through each of the samples and map the reads so that I can
# look at the core and pan OPFs.

# First make a master list of the ORF IDs
sed -n 1~2p ./${Output}/TotalOrfsNuclNoBlock.fa | sed s'/>//g' | sed 's/ .*$//' | sed '1 s/^/Contig_ID\n/' > ./${Output}/MasterOpfList.txt

for file in $(ls ${FastaFiles}/*.nucleotide | sed "s/.*\///g"); do
	GetProteinHits \
		${FastaFiles}/${file} \
		./${Output}/TotalOrfsNuclNoBlock.fa
done


