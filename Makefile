# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Download datasets
./data/PublishedViromeDatasets/*:
	bash ./bin/DownloadPublishedVirome.sh

# Perform quality control
./data/QualityControl:./bin/DownloadPublishedVirome.sh
	bash ./bin/RunQualityControl.sh

# Assemble contigs
./data/AssembledContigs:./bin/DownloadPublishedVirome.sh
	bash ./bin/AssembleContigs.sh
