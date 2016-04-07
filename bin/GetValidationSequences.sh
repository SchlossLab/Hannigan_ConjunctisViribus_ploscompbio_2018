#! /bin/bash
# GetValidationSequences.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export WorkingDirectory=/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet
export PhageValidationAcc=/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet/PhageID.tsv
export BacteriaValidationAcc=/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet/BacteriaID.tsv
export ToolPath=~/git/OpenMetagenomeToolkit/bin/

cd ${WorkingDirectory} || exit

AccString=$(cut -f 2 ${PhageValidationAcc} | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccString}&display=fasta" -O ./ValidationPhage.fa
# Get rid of the block format
perl ~/git/OpenMetagenomeToolkit/bin/remove_block_fasta_format.pl ./ValidationPhage.fa ./ValidationPhageNoBlock.fa

# Also get a fasta for the bacterial genomes being used

AccBacteria=$(cut -f 3 ${BacteriaValidationAcc} | egrep -v 'Taxon' | egrep -v 'NA' | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccBacteria}&display=fasta" -O ./ValidationBacteria.fa
# Get rid of the block format
perl ${ToolPath}remove_block_fasta_format.pl ./ValidationBacteria.fa ./ValidationBacteriaNoBlock.fa
