#!/bin/bash
# PrepareProtClusters.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#PBS -N PrepareProtClusters
#PBS -q first
#PBS -l nodes=1:ppn=1,mem=40gb
#PBS -l walltime=600:00:00
#PBS -j oe
#PBS -V
#PBS -A schloss_lab

################
# Load Modules #
################

module load R/3.2.2

#################
# Set Variables #
#################

# Paths
export WorkingDirectory=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data
export FigureDir=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/figures
export Output='PrepareProtClusters'
export BinPath=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/bin/
export BigBin=/mnt/EXT/Schloss-data/bin/

# Files
export PhageDat=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/phageSVA.dat
export BacteriaDat=/mnt/EXT/Schloss-data/ghannig/Hannigan-2016-ConjunctisViribus/data/bacteriaSVA.dat

# Should we run the benchmarking scripts?
export Benching=false

###########
# Set Env #
###########

cd ${WorkingDirectory} || exit
mkdir ./${Output}

###################
# Set Subroutines #
###################

GetGeneFasta () {
	# 1 = Name
	# 2 = Input dat

	perl ${BinPath}dat2fasta.pl \
		-d "${2}" \
		-f ./${Output}/"${1}"Prot.fa \
		-p \
		-g

	perl -p -i -e 's/ /_/g' ./${Output}/"${1}"Prot.fa #Hmmmmm pie
}

ClusterProteins () {
	# 1 = Name
	# 2 = Input Fasta
	# 3 = Similarity Cutoff Threshold (Default should be 0.9)

	${BigBin}/cd-hit \
		-i "${2}" \
		-o ./${Output}/"${1}"Clustered.fa \
		-c "${3}" \
		-M 64000 \
		-T 8 \
		-d 0

	# Parse the clusters using perl script
	perl ${BinPath}ParseClusters.pl \
		-i ./${Output}/"${1}"Clustered.fa.clstr \
		-o ./${Output}/"${1}"Parsed.tsv
}

GetClusteringStats () {
	# 1 = Input File

	# Remove the file that will be appended to
	rm ./${Output}/BenchmarkingCounts.tsv

	for int in $(seq 0.6 0.05 1); do
		# Get the clusters
		ClusterProteins \
			"Benchmark" \
			"${1}" \
			"${int}"

		# Get how many sequences are in the file
		wc -l ./${Output}/BenchmarkClustered.fa \
			| sed 's/ \+/\t/' \
			| awk -v num="$int" '{print num"\t"$1/2}' \
			>> ./${Output}/BenchmarkingCounts.tsv
	done

	# Plot the results
	Rscript ${BinPath}PlotClusterBenchmark.R \
		-i ./${Output}/BenchmarkingCounts.tsv \
		-o ${FigureDir}/"${2}"BenchmarkingCounts.png
}

export -f GetGeneFasta
export -f ClusterProteins
export -f GetClusteringStats

################
# Run Analysis #
################

# GetGeneFasta \
# 	"Phage" \
# 	${PhageDat}

# GetGeneFasta \
# 	"Bacteria" \
# 	${BacteriaDat}

ClusterProteins \
	"Phage" \
	./${Output}/PhageProt.fa \
	0.6

ClusterProteins \
	"Bacteria" \
	./${Output}/BacteriaProt.fa \
	0.6

if [ "$Benching" = true ] ; then

	GetClusteringStats \
		./${Output}/PhageProt.fa \
		"Phage"
	
	GetClusteringStats \
		./${Output}/BacteriaProt.fa \
		"Bacteria"

fi
