# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Download datasets
:
	bash ./bin/DownloadPublishedVirome.sh

# Perform quality control
:
	bash ./bin/RunQualityControl.sh

# Assemble contigs
:
	bash ./bin/AssembleContigs.sh
