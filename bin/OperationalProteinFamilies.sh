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
		-o "${3}"
}

EstablishOpfs () {
	# 1 = Open Reading Frame fasta

	# Blast them to themselves for clustering
	echo Running Diamond Local Alignment
	GetProteinHits \
		${1} \
		${1} \
		./${Output}/OpfBlastResults.blast

 #    # Cluster the ORFs into OPS using blast output
 #    echo Running Mothur Clustering
 #    ${MothurProg} "#mgcluster(blast=./${Output}/OpfBlastResults.blast, cutoff=0.75)"

 #    # Create alignment file
 #    ${LocalBin}mafft-linux64/mafft.bat \
 #    	${1} \
 #    	> ./${Output}/OrfAlignment.fa

 #    # Create dist matrix for picking representative OPF seqs
 #    ${MothurProg} "#dist.seqs(fasta=./${Output}/OrfAlignment.fa, output=lt)"

 #    # Now get the rep seuqneces
 #    ${MothurProg} "#get.oturep(phylip=./${Output}/OrfAlignment.phylip.dist, list=./${Output}/OpfBlastResults.an.list, fasta=${1}, label=0.22)"

 #    # And format the file
 #    sed -i 's/\t/_/g' ./${Output}/OpfBlastResults.an.0.22.rep.fasta
 #    sed -i 's/|/_/g' ./${Output}/OpfBlastResults.an.0.22.rep.fasta

	# # Make master reference ID list
	# sed -n 1~2p ./${Output}/OpfBlastResults.an.0.22.rep.fasta \
	# | sed s'/>//g' \
	# | sed '1 s/^/Reference_ID\n/' \
	# > ./${Output}/MasterReferenceList.tsv
}

export -f GetProteinHits
export -f EstablishOpfs

################
# Run Analysis #
################

cat ${FastaFiles}/* | sed 's/\*//g' > ./${Output}/TotalOrfs.fa

# Remove block
perl ${RemoveBlock} ./${Output}/TotalOrfs.fa ./${Output}/TotalOrfsNoBlock.fa 

EstablishOpfs ./${Output}/TotalOrfsNoBlock.fa
