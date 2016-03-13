# GetProphagesByBlast.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Pennsylvania
# NOTE: One way to predict whether a phage is associated with a
# bacterium is to determine whether the phage integrates into that
# bacterium. The simplest way to do this is simply using blast to
# determine whether the phage or it's genes are found within the
# bacterial host.

#PBS -N QualityProcess
#PBS -q first
#PBS -l nodes=1:ppn=1,mem=44gb
#PBS -l walltime=500:00:00
#PBS -j oe
#PBS -V
#PBS -A schloss_lab

#######################
# Set the Environment #
#######################
export WorkingDirectory=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data
export Output='InteractionsByBlast'

export PhageGenomes=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/phageSVA.fa
export BacteriaGenomes=/home/ghannig/git/Hannigan-2016-ConjunctisViribus/data/bacteriaSVA.fa
/BacteriaGenomeOrfs.fa

# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

BlastPhageAgainstBacteria () {
	# 1 = Phage Genomes
	# 2 = Bacterial Genomes

	echo Making blast database...
	makeblastdb \
		-dbtype nucl \
		-in ${2} \
		-out ./${Output}/BacteraGenomeReference

	echo Running tblastx...
	tblastx \
    	-query ${1} \
    	-out ./${Output}/PhageToBacteria.tblastx \
    	-db ./${Output}/BacteraGenomeReference \
    	-evalue 1e-3 \
    	-outfmt 6

    echo Formatting blast output...
    # Get the Spacer ID, Phage ID, and Percent Identity
	cut -f 1,2,3 ./${Output}/PhageToBacteria.tblastx \
		| sed 's/_\d\+\t/\t/' \
		> ./${Output}/PhageBacteriaHits.tsv
}

export -f BlastPhageAgainstBacteria

BlastPhageAgainstBacteria \
	${PhageGenomes} \
	${BacteriaGenomes}
