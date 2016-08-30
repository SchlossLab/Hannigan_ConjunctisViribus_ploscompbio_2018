# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#########################
# Set General Variables #
#########################
WORKINGDIRECTORY = ./data

DOWNLOAD = ./data/ViromePublications/*

OBJECTS = \
	./data/ValidationSet/ValidationPhageNoBlock.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa \
	./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv \
	createnetwork \
	./figures/rocCurves.pdf ./figures/rocCurves.png ./figures/ResultHeatmaps.pdf ./figures/ResultHeatmaps.png

all : ${OBJECTS}
download : ${DOWNLOAD}

##########################################
# Download Global Virome Dataset Studies #
##########################################
# Download the sequences for the dataset
./data/ViromePublications/* : ./data/PublishedDatasets/SutdyInformation.tsv
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

# Get the formatted interaction file
./data/ValidationSet/Interactions.tsv : ./data/ValidationSet/BacteriaID.tsv ./data/ValidationSet/InteractionsRaw.tsv
	Rscript ./bin/MergeForInteractions.R \
		-b ./data/ValidationSet/BacteriaID.tsv \
		-i ./data/ValidationSet/InteractionsRaw.tsv \
		-o ./data/ValidationSet/Interactions.tsv

./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv : ./data/ValidationSet/ValidationPhageNoBlock.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa
	bash ./bin/BenchmarkingModel.sh \
		./data/ValidationSet/ValidationPhageNoBlock.fa \
		./data/ValidationSet/ValidationBacteriaNoBlock.fa \
		./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv \
		./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv \
		./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv \
		./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv

createnetwork : ./data/ValidationSet/Interactions.tsv ./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv
	bash ./bin/CreateProteinNetwork

# Run the R script for the validation ROC curve analysis
./figures/rocCurves.pdf ./figures/rocCurves.png ./figures/ResultHeatmaps.pdf ./figures/ResultHeatmaps.png :
	bash ./bin/RunRocAnalysisWithNeo4j.sh
