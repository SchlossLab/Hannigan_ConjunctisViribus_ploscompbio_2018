# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#########################
# Set General Variables #
#########################
WORKINGDIRECTORY = ./data

DOWNLOAD = ./data/ViromePublications

OBJECTS = \
	./data/ValidationSet/ValidationPhageNoBlock.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa \
	./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv

all : ${OBJECTS}
download : ${DOWNLOAD}

##########################################
# Download Global Virome Dataset Studies #
##########################################
# Download the sequences for the dataset
./data/ViromePublications : ./data/PublishedDatasets/SutdyInformation.tsv
	bash ./bin/DownloadPublishedVirome.sh \
		./data/PublishedDatasets/SutdyInformation.tsv

####################
# Model Validation #
####################
# Get the sequences to use in this analysis
./data/ValidationSet/ValidationPhageNoBlock.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa : ./data/ValidationSet/PhageID.tsv ./data/ValidationSet/BacteriaID.tsv
	bash ./bin/GetValidationSequences.sh \
		./data/ValidationSet/PhageID.tsv \
		./data/ValidationSet/BacteriaID.tsv \
		./data/ValidationSet/ValidationPhageNoBlock.fa \
		./data/ValidationSet/ValidationBacteriaNoBlock.fa

./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv : ./data/ValidationSet/ValidationPhageNoBlock.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa
		bash ./bin/BenchmarkingModel.sh \
			./data/ValidationSet/ValidationPhageNoBlock.fa \
			./data/ValidationSet/ValidationBacteriaNoBlock.fa \
			./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv \
			./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv \
			./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv \
			./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv 


