# GetMicrobeOrfs.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Set the variables to be used in this script
export WorkingDirectory=/home/ghannig/projects/PrelimDataModi
export Output='OperationalProteinFamilies'

export MothurProg=/share/scratch/schloss/mothur/mothur

export PhageGenomes=\
	~/git/Hannigan-2016-ConjunctisViribus/data/phageSVA.fa
export BacteriaGenomes=\
	~/git/Hannigan-2016-ConjunctisViribus/data/bacteriaSVA.fa
export InteractionReference=\
	~/git/Hannigan-2016-ConjunctisViribus/data/PhageInteractionReference.tsv

export SwissProt
export Trembl

export GitBin=/home/ghannig/git/HanniganNotebook/bin/
export SeqtkPath=/home/ghannig/bin/seqtk/seqtk
export LocalBin=/home/ghannig/bin/

# Make the output directory and move to the working directory
echo Creating output directory...
cd ${WorkingDirectory}
mkdir ./${Output}

PredictOrfs () {
	# 1 = Contig Fasta File for Glimmer
	# 2 = Output File Name

	${LocalBin}glimmer3.02/bin/build-icm ./${Output}/Contigs.icm < ${1}

	${LocalBin}glimmer3.02/bin/glimmer3 \
		--linear \
		-g 100 \
		${1} \
		./${Output}/Contigs.icm \
		./${Output}/GlimmerOut

	cat ./${Output}/GlimmerOut.predict | while read line;
    do if [ "${line:0:1}" == ">" ]
        then seqname=${line#'>'}
        else
        orf="$seqname.${line%%' '*}"
        coords="${line#*' '}"
        echo -e "$orf\t$seqname\t$coords"
        fi
    done > ./${Output}/GlimmerOutFormat.predict

    ${LocalBin}glimmer3.02/bin/multi-extract \
    	-l 100 \
    	--nostop \
    	${1} \
    	./${Output}/GlimmerOutFormat.predict \
    	> ./${Output}/tmp-ContigOrfs.fa

    # Remove the block formatting
	perl \
	${GitBin}remove_block_fasta_format.pl \
		./${Output}/tmp-ContigOrfs.fa \
		./${Output}/${2}

	# Remove the tmp file
	rm ./${Output}/tmp-ContigOrfs.fa
}

SubsetUniprot () {
	# 1 = Interaction Reference File
	# 2 = SwissProt Database No Block
	# 3 = Trembl Database No Block

	# Note that database should cannot be in block format
	# Create a list of the accession numbers
	cut -f 1,2 ${1} \
		| grep -v "interactor" \
		| sed 's/uniprotkb\://g' \
		> ./${Output}/ParsedInteractionRef.tsv

	# Collapse that list to single column of unique IDs
	sed 's/\t/\n/' ./${Output}/ParsedInteractionRef.tsv \
		| sort \
		| uniq \
		> ./${Output}/UniqueInteractionRef.tsv

	# Use this list to subset the Uniprot database
	perl ${GitBin}FilterFasta.pl \
		-i ${2} \
		-l ./${Output}/UniqueInteractionRef.tsv \
		-o ./${Output}/SwissProtSubset.fa
	perl ${GitBin}FilterFasta.pl \
		-i ${3} \
		-l ./${Output}/UniqueInteractionRef.tsv \
		-o ./${Output}/TremblProtSubset.fa

	# Create single file with two datasets
	cat \
		./${Output}/SwissProtSubset.fa \
		./${Output}/TremblProtSubset.fa \
		> ./${Output}/TotalUniprotSubset.fa
}

export -f PredictOrfs

PredictOrfs ${PhageGenomes} "PhageGenomeOrfs.fa"
PredictOrfs ${BacteriaGenomes} "BacteriaGenomeOrfs.fa"



