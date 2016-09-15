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
	validationnetwork \
	./figures/rocCurves.pdf ./figures/rocCurves.png \

validation : ${VALIDATION}
all : ${VALIDATION} ${SAMPLELIST}
download : ${DOWNLOAD}

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
		./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv \
		"BenchmarkingSet"

validationnetwork : ./data/ValidationSet/Interactions.tsv ./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork \
		./data/ValidationSet/Interactions.tsv \
		./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv \
		./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv \
		./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv \
		./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv \
		"TRUE"

# Run the R script for the validation ROC curve analysis
./figures/rocCurves.pdf ./figures/rocCurves.png : ./data/ValidationSet/Interactions.tsv ./data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv ./data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv ./data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv ./data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv
	bash ./bin/RunRocAnalysisWithNeo4j.sh

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

############################
# Total Dataset Networking #
############################
### CONTIG ASSEMBLY AND QC

# Run quality control as well here
# Need to decompress the fastq files first from SRA
${SAMPLELIST}: %: ./data/ViromePublications ./data/PublishedDatasets/metadatatable.tsv
	echo $@
	bash ./bin/QcAndContigs.sh \
		$@ \
		./data/ViromePublications/ \
		./data/PublishedDatasets/metadatatable.tsv \
		"QualityOutput"

# Merge the contigs into a single file
./data/TotalCatContigs.fa : ./data/QualityOutput
	bash ./bin/catcontigs.sh ./data/QualityOutput ./data/TotalCatContigs.fa

# Generate a contig relative abundance table
./data/ContigRelAbundForGraph.tsv : ./data/TotalCatContigs.fa ./data/QualityOutput/raw
	bash ./bin/CreateContigRelAbundTable.sh \
		./data/TotalCatContigs.fa \
		./data/QualityOutput/raw \
		./data/ContigRelAbundForGraph.tsv

### CONTIG STATISTICS

# Prepare to plot contig stats like sequencing depth, length, and circularity
./data/PhageContigStats/ContigLength.tsv ./data/PhageContigStats/FinalContigCounts.tsv ./data/PhageContigStats/circularcontigsFormat.tsv : ./data/TotalCatContigs.fa ./data/ContigRelAbundForGraph.tsv
	bash ./bin/contigstats.sh \
		./data/TotalCatContigs.fa \
		./data/ContigRelAbundForGraph.tsv \
		./data/PhageContigStats/ContigLength.tsv \
		./data/PhageContigStats/FinalContigCounts.tsv \
		./data/PhageContigStats/circularcontigsFormat.tsv \
		./data/PhageContigStats

# Finalize the contig stats plots
./figures/ContigStats.pdf ./figures/ContigStats.png : ./data/PhageContigStats/ContigLength.tsv ./data/PhageContigStats/FinalContigCounts.tsv ./data/PhageContigStats/circularcontigsFormat.tsv
	Rscript ./bin/FinalizeContigStats.R \
		-l ./data/PhageContigStats/ContigLength.tsv \
		-c ./data/PhageContigStats/FinalContigCounts.tsv \
		-x ./data/PhageContigStats/circularcontigsFormat.tsv

### DRAW PRIMARY NETWORK GRAPH (PHAGE + REFERENCE BACTERA)

# In this case the samples will get run against the bacteria reference genome set
./data/ViromeAgainstReferenceBacteria/BenchmarkCrisprsFormat.tsv ./data/ViromeAgainstReferenceBacteria/BenchmarkProphagesFormatFlip.tsv ./data/ViromeAgainstReferenceBacteria/MatchesByBlastxFormatOrder.tsv ./data/ViromeAgainstReferenceBacteria/PfamInteractionsFormatScoredFlip.tsv : ./data/TotalCatContigs.fa ./data/ValidationSet/ValidationBacteriaNoBlock.fa
	bash ./bin/BenchmarkingModel.sh \
		./data/TotalCatContigs.fa \
		./data/ValidationSet/ValidationBacteriaNoBlock.fa \
		./data/ViromeAgainstReferenceBacteria/BenchmarkCrisprsFormat.tsv \
		./data/ViromeAgainstReferenceBacteria/BenchmarkProphagesFormatFlip.tsv \
		./data/ViromeAgainstReferenceBacteria/MatchesByBlastxFormatOrder.tsv \
		./data/ViromeAgainstReferenceBacteria/PfamInteractionsFormatScoredFlip.tsv \
		"ViromeAgainstReferenceBacteria"

# Make a graph database from the experimental information
expnetwork : ./data/ValidationSet/Interactions.tsv ./data/ViromeAgainstReferenceBacteria/BenchmarkCrisprsFormat.tsv ./data/ViromeAgainstReferenceBacteria/BenchmarkProphagesFormatFlip.tsv ./data/ViromeAgainstReferenceBacteria/PfamInteractionsFormatScoredFlip.tsv ./data/ViromeAgainstReferenceBacteria/MatchesByBlastxFormatOrder.tsv
	# Note that this resets the graph database and erases
	# the validation information we previously added.
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork \
		./data/ValidationSet/Interactions.tsv \
		./data/ViromeAgainstReferenceBacteria/BenchmarkCrisprsFormat.tsv \
		./data/ViromeAgainstReferenceBacteria/BenchmarkProphagesFormatFlip.tsv \
		./data/ViromeAgainstReferenceBacteria/PfamInteractionsFormatScoredFlip.tsv \
		./data/ViromeAgainstReferenceBacteria/MatchesByBlastxFormatOrder.tsv \
		"FALSE"

# Predict interactions between nodes
./data/PredictedRelationshipTable.tsv : ./data/rfinteractionmodel.RData
	bash ./bin/RunPredictionsWithNeo4j.sh ./data/rfinteractionmodel.RData ./data/PredictedRelationshipTable.tsv

# Add relationships
finalrelationships : ./data/PredictedRelationshipTable.tsv
	bash ./bin/AddRelationshipWrapper.sh \
		./data/PredictedRelationshipTable.tsv



