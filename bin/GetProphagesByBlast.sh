#! /bin/bash
# GetProphagesByBlast.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Pennsylvania
# NOTE: One way to predict whether a phage is associated with a
# bacterium is to determine whether the phage integrates into that
# bacterium. The simplest way to do this is simply using blast to
# determine whether the phage or it's genes are found within the
# bacterial host.

#######################
# Set the Environment #
#######################
export WorkingDirectory=${5}
export Output='tmp'
export BlastPath=/scratch/pschloss_flux/ghannig/bin/ncbi-blast-2.3.0+/bin/
export SchlossBin=/scratch/pschloss_flux/ghannig/bin/

export PhageGenomes=${1}
export BacteriaGenomes=${2}
export OutputFile=${3}
export SecondOutFile=${4}
export PhageOrfs=${6}
export BacteriaOrfs=${7}

# Make the output directory and move to the working directory
echo Creating output directory...
cd "${WorkingDirectory}" || exit
mkdir ./${Output}

BlastPhageAgainstBacteria () {
	# 1 = Phage Genomes
	# 2 = Bacterial Genomes

	echo Making blast database...
	${BlastPath}makeblastdb \
		-dbtype nucl \
		-in "${2}" \
		-out ./${Output}/BacteraGenomeReference

	echo Running blastn...
	${BlastPath}blastn \
    	-query "${1}" \
    	-out ./${Output}/PhageToBacteria.blastn \
    	-db ./${Output}/BacteraGenomeReference \
    	-evalue 1e10 \
    	-num_threads 8\
    	-outfmt 6

    echo Formatting blast output...
    # Get the Spacer ID, Phage ID, and BitScore
	cut -f 1,2,12 ./${Output}/PhageToBacteria.blastn \
		| sed 's/_\d\+\t/\t/' \
		> "${3}"

	# Now look at the genes with diamond
	# Make database
	echo Making Diamond Database...
	${SchlossBin}diamond makedb \
		--in "${5}" \
		-d ./${Output}/PhageOrfsDiamond

	echo Running Phage ORFs...
	${SchlossBin}diamond blastx \
		-q "${6}" \
		-d ./${Output}/PhageOrfsDiamond \
		-a ./${Output}/PhageOrfToBacteria.daa \
		-t ./

	${SchlossBin}diamond view \
		-a ./${Output}/PhageOrfToBacteria.daa \
		-o ./${Output}/PhageOrfToBacteriaResults.txt
}

export -f BlastPhageAgainstBacteria

BlastPhageAgainstBacteria \
	"${PhageGenomes}" \
	"${BacteriaGenomes}" \
	"${OutputFile}" \
	"${SecondOutFile}" \
	"${PhageOrfs}" \
	"${BacteriaOrfs}"

# Remove the tmp output file
rm -r ./${Output}
