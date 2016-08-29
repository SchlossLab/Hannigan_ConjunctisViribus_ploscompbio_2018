#! /bin/bash
# GetValidationSequences.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export PhageValidationAcc=$1
export BacteriaValidationAcc=$2
export PhageOutput=$3
export BacteriaOutput=$4

AccString=$(cut -f 2 ${PhageValidationAcc} | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccString}&display=fasta" -O ./ValidationPhage.fa
# Get rid of the block format
perl ./bin/remove_block_fasta_format.pl ./ValidationPhage.fa ./ValidationPhageNoBlockint.fa
perl -pe 's/^>ENA\S+\s/>/' ./ValidationPhageNoBlockint.fa \
	| perl -pe 's/\, .*//' \
	| perl -pe 's/ complete.*//' \
	| perl -pe 's/\h/_/g' \
	> "${PhageOutput}"
rm ./ValidationPhage.fa
rm ./ValidationPhageNoBlockint.fa

# Also get a fasta for the bacterial genomes being used

AccBacteria=$(cut -f 3 ${BacteriaValidationAcc} | egrep -v 'Taxon' | egrep -v 'NA' | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccBacteria}&display=fasta" -O ./ValidationBacteria.fa
# Get rid of the block format
perl ./bin/remove_block_fasta_format.pl ./ValidationBacteria.fa ./ValidationBacteriaNoBlockint.fa
perl -pe 's/^>ENA\S+\s/>/' ./ValidationBacteriaNoBlockint.fa \
	| perl -pe 's/\, .*//' \
	| perl -pe 's/ complete.*//' \
	| perl -pe 's/\h/_/g' \
	> "${BacteriaOutput}"
rm ./ValidationBacteria.fa
rm ./ValidationBacteriaNoBlockint.fa
