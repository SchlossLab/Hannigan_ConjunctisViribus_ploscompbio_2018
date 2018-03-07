# # Get the virus genbank files that contain host information
# mkdir -p ./data/genbankPhageHost
# wget -O ./data/genbankPhageHost/viral.1.genomic.gbff.gz "ftp://ftp.ncbi.nih.gov/refseq/release/viral/viral.1.genomic.gbff.gz"
# wget -O ./data/genbankPhageHost/viral.2.genomic.gbff.gz "ftp://ftp.ncbi.nih.gov/refseq/release/viral/viral.2.genomic.gbff.gz"

# # Unzip the files
# gunzip ./data/genbankPhageHost/viral.*.genomic.gbff.gz

# Parse the genbank files to get phages and hosts (lab strains primarily)
python ./bin/Genbank2phagehost.py \
	-i ./data/genbankPhageHost/viral.1.genomic.gbff \
	-o ./data/genbankPhageHost/viral.1.tsv

python ./bin/Genbank2phagehost.py \
	-i ./data/genbankPhageHost/viral.2.genomic.gbff \
	-o ./data/genbankPhageHost/viral.2.tsv

cat ./data/genbankPhageHost/VirRef/viral.*.tsv > ./data/genbankPhageHost/VirRef/viral.tsv

# As a filter for strain level, only get values where the host has more than
# a placeholder for species and genus (two placeholders)
egrep "\t.+\s.+\s" ./data/genbankPhageHost/viral.tsv > ./data/genbankPhageHost/viral_hoststrain.tsv

# Get just the viruses for parsing with grep
cut -f 1 \
	./data/genbankPhageHost/viral_hoststrain.tsv \
	> ./data/genbankPhageHost/virusphage.tsv

cut -f 2 \
	viral_hoststrain.tsv \
	| sed 's/^/\^>\.\+/' \
	| sed 's/$/, complete genome\$/' \
	> bacteriahosts.tsv

# Pull out the source information from NCBI viral references
# Bacteria
mkdir -p ./data/genbankPhageHost/BacRef
wget -r --no-parent -A 'bacteria.*.1.genomic.fna.gz' "ftp://ftp.ncbi.nih.gov/refseq/release/bacteria/"
mv ftp.ncbi.nih.gov/refseq/release/bacteria/bacteria.*.1.genomic.fna.gz ./data/genbankPhageHost/BacRef/
rm -r ftp.ncbi.nih.gov
gunzip ./data/genbankPhageHost/BacRef/*

ls ./BacRef | xargs -I {} --max-procs=8 perl ../../bin/remove_block_fasta_format.pl ./BacRef/{} ./BacRef/noblock_{}

cat ./data/genbankPhageHost/BacRef/noblock_*.fna > ./data/genbankPhageHost/BacRef/bacteria.genomic.fna

ls ./BacRef | xargs -I {} --max-procs=16  sh -c 'egrep -A 1 --file=bacteriahosts.tsv ./BacRef/noblock_"$1" > ./BacRef/noblock_"$1.out"' -- {}

rm ./BacRef/noblock_noblock_*

cat ./BacRef/noblock_bacteria.*out > ./BacRef/filtered.bacteria.fa


# Virus
mkdir -p ./data/genbankPhageHost/VirRef
wget -r --no-parent -A 'viral.*.1.genomic.fna.gz' "ftp://ftp.ncbi.nih.gov/refseq/release/viral/"
mv ftp.ncbi.nih.gov/refseq/release/viral/viral.*.1.genomic.fna.gz ./data/genbankPhageHost/VirRef/
rm -r ftp.ncbi.nih.gov
gunzip ./data/genbankPhageHost/VirRef/*
cat ./data/genbankPhageHost/VirRef/*.fna > ./data/genbankPhageHost/VirRef/viral.genomic.fna
perl ./bin/remove_block_fasta_format.pl \
	./data/genbankPhageHost/VirRef/viral.genomic.fna \
	./data/genbankPhageHost/VirRef/viral.genomic.noblock.fa
# Filter fasta for complete reference phages with host information
grep \
	-A 1 \
	--file=./data/genbankPhageHost/virusphage.tsv \
	./data/genbankPhageHost/VirRef/viral.genomic.noblock.fa \
	| grep -A 1 "complete genome" \
	| egrep -v '\-\-' \
	> ./data/genbankPhageHost/VirRef/filtered.virus.fa


# Instead of bacterial strains, do species level genomes (complete genomes)
# Break down bacteria to species level
sed 's/\t\([a-zA-Z0-9]\+ [a-zA-Z0-9]\+\).*$/\t\1/' ./viral.tsv > ./viral_host_species.tsv

cut -f 2 \
	viral_host_species.tsv \
	| sed 's/^/\^>\.\+/' \
	| sed 's/$/\.\+, complete genome\$/' \
	| sort \
	| uniq \
	> bacteriahosts_species.tsv

ls ./BacRef | xargs -I {} --max-procs=16 sh -c 'egrep -A 1 --file=bacteriahosts_species.tsv ./BacRef/noblock_"$1" > ./BacRef/noblock_"$1.species"' -- {}

rm ./BacRef/noblock_noblock_*

cat ./BacRef/noblock_*.species \
	| egrep -v '^\-\-' \
	> ./BacRef/bacteria.complete.species.fa

# Also get species with shotgun sequences
cut -f 2 \
	viral_host_species.tsv \
	| sed 's/^/\^>\.\+/' \
	| sed 's/$/\.\+, whole genome shotgun sequence\$/' \
	| sort \
	| uniq \
	> bacteriahosts_species_wgs.tsv

ls ./BacRef | xargs -I {} --max-procs=16 sh -c 'egrep -A 1 --file=bacteriahosts_species_wgs.tsv ./BacRef/noblock_"$1" > ./BacRef/noblock_"$1.swgs"' -- {}

rm ./BacRef/noblock_noblock_*




