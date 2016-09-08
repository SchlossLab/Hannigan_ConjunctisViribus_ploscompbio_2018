# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#########################
# Set General Variables #
#########################
ACCLIST := $(shell awk '{ print "data/ViromePublications/"$$7 }' ./data/PublishedDatasets/SutdyInformation.tsv)
SAMPLELIST := $(shell awk '{ print $$3 }' ./data/PublishedDatasets/metadatatable.tsv | sort | uniq)

# For debugging right now
print:
	echo ${SAMPLELIST}

DOWNLOAD = ${ACCLIST}

VALIDATION = \
	./data/ValidationSet/ValidationPhageNoBlock.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa \
	./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv \
	../../bin/neo4j-enterprise-2.3.0/data/graph.db \
	./figures/rocCurves.pdf ./figures/rocCurves.png

validation : ${VALIDATION}
all : ${VALIDATION} ${SAMPLELIST}
download : ${DOWNLOAD}

# ##########################################
# # Download Global Virome Dataset Studies #
# ##########################################
# Download the sequences for the dataset
# Use the list because it allows for test of targets
$(ACCLIST): %: ./data/PublishedDatasets/SutdyInformation.tsv
	echo $@
	bash ./bin/DownloadPublishedVirome.sh \
		$< \
		$@

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

../../bin/neo4j-enterprise-2.3.0/data/graph.db : ./data/ValidationSet/Interactions.tsv ./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv ../../bin/neo4j-enterprise-2.3.0/data/graph.db
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork

# Run the R script for the validation ROC curve analysis
./figures/rocCurves.pdf ./figures/rocCurves.png : ./data/ValidationSet/Interactions.tsv ./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv
	bash ./bin/RunRocAnalysisWithNeo4j.sh

############################
# Total Dataset Processing #
############################
# Run quality control and contig assembly
# Need to decompress the fastq files first from SRA
${SAMPLELIST}: %: ./data/ViromePublications ./data/PublishedDatasets/metadatatable.tsv
	echo $@
	bash ./bin/QcAndContigs.sh \
		$@ \
		./data/ViromePublications/ \
		./data/PublishedDatasets/metadatatable.tsv \
		"QualityOutput"


