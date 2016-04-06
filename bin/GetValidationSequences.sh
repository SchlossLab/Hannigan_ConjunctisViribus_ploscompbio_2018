# GetValidationSequences.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

export WorkingDirectory=/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet
export PhageValidationAcc=/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet/PhageID.tsv
export BacteriaValidationAcc=/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/data/ValidationSet/BacteriaID.tsv

cd ${WorkingDirectory}

export AccString=$(cut -f 2 ${PhageValidationAcc} | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccString}&display=fasta" -O ./ValidationPhage.fa

# Also get a fasta for the bacterial genomes being used

export AccBacteria=$(cut -f 3 ${BacteriaValidationAcc} | egrep -v 'Taxon' | egrep -v 'NA' | tr '\n' ',' | sed 's/,$//')

wget "http://www.ebi.ac.uk/ena/data/view/${AccBacteria}&display=fasta" -O ./ValidationBacteria.fa
