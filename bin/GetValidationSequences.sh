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
perl -pe 's/^>ENA\|(.+)\|.*/>$1/' ./ValidationPhageNoBlockint.fa \
	> ./tmpholder.fa

# Replace the fasta IDs with names from the original id list.
awk -F "\t" 'FNR==NR { a[">"$2] = $1; next } { if (a[$1]) {print ">"a[$1]} else {print $1} }' \
	${PhageValidationAcc} \
	./tmpholder.fa \
	> "${PhageOutput}"

rm ./ValidationPhage.fa
rm ./ValidationPhageNoBlockint.fa
rm ./tmpholder.fa

echo Finished processing phage validation set!

# Also get a fasta for the bacterial genomes being used

AccBacteria=$(cut -f 3 ${BacteriaValidationAcc} | egrep -v 'Taxon' | egrep -v 'NA' | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccBacteria}&display=fasta" -O ./ValidationBacteria.fa
# Get rid of the block format
perl ./bin/remove_block_fasta_format.pl ./ValidationBacteria.fa ./ValidationBacteriaNoBlockint.fa
perl -pe 's/^>ENA\|(.+)\|.*/>$1/' ./ValidationBacteriaNoBlockint.fa \
	> ./tmpholder.fa

# Replace the fasta IDs with names from the original id list.
awk -F "\t" 'FNR==NR { a[">"$2] = $1; next } { if (a[$1]) {print ">"a[$1]} else {print $1} }' \
	${BacteriaValidationAcc} \
	./tmpholder.fa \
	> "${BacteriaOutput}"

rm ./ValidationBacteria.fa
rm ./ValidationBacteriaNoBlockint.fa
rm ./tmpholder.fa

echo Finished processing bacteria validation set!
