# Get the virus genbank files that contain host information
mkdir -p ./data/genbankPhageHost
wget -O ./data/genbankPhageHost/viral.1.genomic.gbff.gz "ftp://ftp.ncbi.nih.gov/refseq/release/viral/viral.1.genomic.gbff.gz"
wget -O ./data/genbankPhageHost/viral.2.genomic.gbff.gz "ftp://ftp.ncbi.nih.gov/refseq/release/viral/viral.2.genomic.gbff.gz"

# Unzip the files
gunzip ./data/genbankPhageHost/viral.*.genomic.gbff.gz

# Parse the genbank files to get phages and hosts (lab strains primarily)
python ./bin/Genbank2phagehost.py \
	-i ./data/genbankPhageHost/viral.1.genomic.gbff \
	-o ./data/genbankPhageHost/viral.1.tsv

python ./bin/Genbank2phagehost.py \
	-i ./data/genbankPhageHost/viral.2.genomic.gbff \
	-o ./data/genbankPhageHost/viral.2.tsv

# Pull out the source information from NCBI viral references

