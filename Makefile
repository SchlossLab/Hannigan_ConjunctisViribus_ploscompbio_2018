# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##############################
# Download & Format Metadata #
##############################
# That specific metadata file needs to be obtained from this address"
# https://trace.ncbi.nlm.nih.gov/Traces/study/?acc=ERP008725&go=go
DownloadMetadata : ./bin/DownloadMetadata.sh ./data/PublishedDatasets/raw_metadata/Sra-ERP008725.txt
	bash ./bin/DownloadMetadata.sh \
		./data/PublishedDatasets/SutdyInformation.tsv

./data/PublishedDatasets/metadatatable.tsv : ./data/PublishedDatasets/SubjectSampleInformation.tsv
	Rscript ./bin/ParseSraTable.R \
		-i "./data/PublishedDatasets/Sra-*" \
		-m ./data/PublishedDatasets/SubjectSampleInformation.tsv \
		-o ./data/PublishedDatasets/metadatatable.tsv



#########################
# Set General Variables #
#########################
ACCLIST := $(shell awk '{ print "data/ViromePublications/"$$7 }' ./data/PublishedDatasets/SutdyInformation.tsv)
SAMPLELIST := $(shell awk '{ print $$3 }' ./data/PublishedDatasets/metadatatable.tsv | sort | uniq)
DATENAME := $(shell date | sed 's/ /_/g' | sed 's/\:/\./g')

# For debugging right now
print:
	echo $(shell date)"\t"Printing sample list"\n" >> ${DATENAME}.makelog
	echo ${SAMPLELIST}



#############
# Set Rules #
#############
contigs: ${SAMPLELIST}

runsamples : DownloadMetadata $(samplesforcleaning)

####################
# Model Validation #
####################
VALDIR=./data/ValidationSet

# Get the sequences to use in this analysis
${VALDIR}/ValidationPhageNoBlock.fa \
${VALDIR}/ValidationBacteriaNoBlock.fa : \
			${VALDIR}/PhageID.tsv \
			${VALDIR}/BacteriaID.tsv \
			./bin/GetValidationSequences.sh
	echo $(shell date)"\t"Downloading validation sequences"\n" >> ${DATENAME}.makelog
	bash ./bin/GetValidationSequences.sh \
		${VALDIR}/PhageID.tsv \
		${VALDIR}/BacteriaID.tsv \
		${VALDIR}/ValidationPhageNoBlock.fa \
		${VALDIR}/ValidationBacteriaNoBlock.fa

# Get the formatted interaction file
${VALDIR}/Interactions.tsv : \
			${VALDIR}/BacteriaID.tsv \
			${VALDIR}/InteractionsRaw.tsv \
			./bin/MergeForInteractions.R
	echo $(shell date)"\t"Formatting interaction file"\n" >> ${DATENAME}.makelog
	Rscript ./bin/MergeForInteractions.R \
		-b ${VALDIR}/BacteriaID.tsv \
		-i ${VALDIR}/InteractionsRaw.tsv \
		-o ${VALDIR}/Interactions.tsv

BSET=./data/BenchmarkingSet

${BSET}/BenchmarkCrisprsFormat.tsv \
${BSET}/BenchmarkProphagesFormatFlip.tsv \
${BSET}/MatchesByBlastxFormatOrder.tsv \
${BSET}/PfamInteractionsFormatScoredFlip.tsv : \
			${VALDIR}/ValidationPhageNoBlock.fa \
			${VALDIR}/ValidationBacteriaNoBlock.fa \
			./bin/BenchmarkingModel.sh
	echo $(shell date)"\t"Calculating values for interaction predictive model"\n" >> ${DATENAME}.makelog
	bash ./bin/BenchmarkingModel.sh \
		${VALDIR}/ValidationPhageNoBlock.fa \
		${VALDIR}/ValidationBacteriaNoBlock.fa \
		${BSET}/BenchmarkCrisprsFormat.tsv \
		${BSET}/BenchmarkProphagesFormatFlip.tsv \
		${BSET}/MatchesByBlastxFormatOrder.tsv \
		${BSET}/PfamInteractionsFormatScoredFlip.tsv \
		"BenchmarkingSet"

validationnetwork : \
			${VALDIR}/Interactions.tsv \
			${BSET}/BenchmarkCrisprsFormat.tsv \
			${BSET}/BenchmarkProphagesFormatFlip.tsv \
			${BSET}/PfamInteractionsFormatScoredFlip.tsv \
			${BSET}/MatchesByBlastxFormatOrder.tsv \
			./bin/CreateProteinNetwork
	echo $(shell date)"\t"Building graph using validation dataset values for prediction"\n" >> ${DATENAME}.makelog
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork \
		${VALDIR}/Interactions.tsv \
		${BSET}/BenchmarkCrisprsFormat.tsv \
		${BSET}/BenchmarkProphagesFormatFlip.tsv \
		${BSET}/PfamInteractionsFormatScoredFlip.tsv \
		${BSET}/MatchesByBlastxFormatOrder.tsv \
		"TRUE"

# Run the R script for the validation ROC curve analysis
./figures/rocCurves.pdf \
./figures/rocCurves.png \
./data/rfinteractionmodel.RData : \
			validationnetwork \
			${VALDIR}/Interactions.tsv \
			${BSET}/BenchmarkCrisprsFormat.tsv \
			${BSET}/BenchmarkProphagesFormatFlip.tsv \
			${BSET}/PfamInteractionsFormatScoredFlip.tsv \
			${BSET}/MatchesByBlastxFormatOrder.tsv \
			./bin/RunRocAnalysisWithNeo4j.sh
	echo $(shell date)"\t"Predicting interactions between phages and bacteria in graph"\n" >> ${DATENAME}.makelog
	bash ./bin/RunRocAnalysisWithNeo4j.sh


# ##########################################
# # Download Global Virome Dataset Studies #
# ##########################################
# Download the sequences for the dataset
# Use the list because it allows for test of targets
$(ACCLIST): %: ./data/PublishedDatasets/SutdyInformation.tsv ./bin/DownloadPublishedVirome.sh
	echo $@
	echo $(shell date)"\t"Downloading study sample sequences from $@"\n" >> ${DATENAME}.makelog
	bash ./bin/DownloadPublishedVirome.sh \
		$< \
		$@



############################
# Total Dataset Networking #
############################
### CONTIG ASSEMBLY AND QC

# Run quality control as well here
# Need to decompress the fastq files first from SRA
${SAMPLELIST}: %: ./data/ViromePublications ./data/PublishedDatasets/metadatatable.tsv ./bin/QcAndContigs.sh
	echo Makefile is calling to process $@
	echo $(shell date)"\t"Performing QC and contig alignment on sample $@"\n" >> ${DATENAME}.makelog
	bash ./bin/QcAndContigs.sh \
		$@ \
		./data/ViromePublications/ \
		./data/PublishedDatasets/metadatatable.tsv \
		"QualityOutput"

# Merge the contigs into a single file
./data/TotalCatContigsBacteria.fa \
./data/TotalCatContigsPhage.fa \
./data/TotalCatContigs.fa : \
			${SAMPLELIST} \
			./data/PublishedDatasets/metadatatable.tsv \
			./bin/catcontigs.sh
	echo $(shell date)"\t"Merging contigs into single file"\n" >> ${DATENAME}.makelog
	bash ./bin/catcontigs.sh \
		./data/QualityOutput \
		./data/TotalCatContigsBacteria.fa \
		./data/TotalCatContigsPhage.fa \
		./data/PublishedDatasets/metadatatable.tsv \
		./data/TotalCatContigs.fa

# At this point I have two contig files that I need to keep straight
# One for bacteria, one for phage

# Generate a contig relative abundance table
./data/ContigRelAbundForGraph.tsv : \
			./data/TotalCatContigs.fa \
			${SAMPLELIST} \
			./bin/CreateContigRelAbundTable.sh
	echo $(shell date)"\t"Generating contig sequence abundance table"\n" >> ${DATENAME}.makelog
	bash ./bin/CreateContigRelAbundTable.sh \
		./data/TotalCatContigs.fa \
		./data/QualityOutput/raw \
		./data/ContigRelAbundForGraph.tsv

# Split abundance table by phage and bacteria samples/contigs
./data/BacteriaContigAbundance.tsv \
./data/PhageContigAbundance.tsv : \
			./data/TotalCatContigsBacteria.fa \
			./data/TotalCatContigsPhage.fa \
			./data/PublishedDatasets/metadatatable.tsv \
			./data/ContigRelAbundForGraph.tsv \
			./bin/SepAbundanceTable.sh
	echo $(shell date)"\t"Split contig abundance table between phage and bacteria"\n" >> ${DATENAME}.makelog
	bash ./bin/SepAbundanceTable.sh \
		./data/PublishedDatasets/metadatatable.tsv \
		./data/TotalCatContigsBacteria.fa \
		./data/TotalCatContigsPhage.fa \
		./data/BacteriaContigAbundance.tsv \
		./data/PhageContigAbundance.tsv \
		./data/ContigRelAbundForGraph.tsv

# Transform contig abundance table for CONCOCT
## Bacteria
./data/ContigRelAbundForConcoctBacteria.tsv : \
			./data/BacteriaContigAbundance.tsv \
			./bin/ReshapeAlignedAbundance.R
	echo $(shell date)"\t"Transforming bacteria abundance table for CONCOCT"\n" >> ${DATENAME}.makelog
	Rscript ./bin/ReshapeAlignedAbundance.R \
		-i ./data/BacteriaContigAbundance.tsv \
		-o ./data/ContigRelAbundForConcoctBacteria.tsv \
		-p 0.15
## Phage
./data/ContigRelAbundForConcoctPhage.tsv : \
			./data/PhageContigAbundance.tsv \
			./bin/ReshapeAlignedAbundance.R
	echo $(shell date)"\t"Transforming phage abundance table for CONCOCT"\n" >> ${DATENAME}.makelog
	Rscript ./bin/ReshapeAlignedAbundance.R \
		-i ./data/PhageContigAbundance.tsv \
		-o ./data/ContigRelAbundForConcoctPhage.tsv \
		-p 0.15

# Run CONCOCT to get contig clusters
# Read length is an approximate average from the studies
# Im skipping total coverage because I don't think it makes sense for this dataset
# Again do it as bacteria and phages
concoctify : ./data/ContigClustersBacteria ./data/ContigClustersPhage
## Bacteroa
./data/ContigClustersBacteria \
./data/ContigClustersBacteria/clustering_gt1000.csv: \
			./data/TotalCatContigsBacteria.fa \
			./data/ContigRelAbundForConcoctBacteria.tsv
	echo $(shell date)"\t"Clustering bacterial contigs using CONCOCT"\n" >> ${DATENAME}.makelog
	mkdir ./data/ContigClustersBacteria
	concoct \
		--coverage_file ./data/ContigRelAbundForConcoctBacteria.tsv \
		--composition_file ./data/TotalCatContigsBacteria.fa \
		--clusters 500 \
		--kmer_length 5 \
		--length_threshold 1000 \
		--read_length 150 \
		--basename ./data/ContigClustersBacteria/ \
		--no_total_coverage \
		--iterations 50
##Phage
./data/ContigClustersPhage \
./data/ContigClustersPhage/clustering_gt1000.csv : \
			./data/TotalCatContigsPhage.fa \
			./data/ContigRelAbundForConcoctPhage.tsv
	echo $(shell date)"\t"Clustering phage contigs using CONCOCT"\n" >> ${DATENAME}.makelog
	mkdir ./data/ContigClustersPhage
	concoct \
		--coverage_file ./data/ContigRelAbundForConcoctPhage.tsv \
		--composition_file ./data/TotalCatContigsPhage.fa \
		--clusters 500 \
		--kmer_length 5 \
		--length_threshold 1000 \
		--read_length 150 \
		--basename ./data/ContigClustersPhage/ \
		--no_total_coverage \
		--iterations 50


### CONTIG STATISTICS
PSTAT=./data/PhageContigStats

# Prepare to plot contig stats like sequencing depth, length, and circularity
${PSTAT}/ContigLength.tsv \
${PSTAT}/FinalContigCounts.tsv \
${PSTAT}/circularcontigsFormat.tsv : \
			./data/TotalCatContigs.fa \
			./data/ContigRelAbundForGraph.tsv \
			./bin/contigstats.sh
	echo $(shell date)"\t"Calculating contig statistics"\n" >> ${DATENAME}.makelog
	bash ./bin/contigstats.sh \
		./data/TotalCatContigs.fa \
		./data/ContigRelAbundForGraph.tsv \
		${PSTAT}/ContigLength.tsv \
		${PSTAT}/FinalContigCounts.tsv \
		${PSTAT}/circularcontigsFormat.tsv \
		${PSTAT}

# Finalize the contig stats plots
./figures/ContigStats.pdf \
./figures/ContigStats.png : \
			${PSTAT}/ContigLength.tsv \
			${PSTAT}/FinalContigCounts.tsv \
			${PSTAT}/circularcontigsFormat.tsv \
			./bin/FinalizeContigStats.R
	echo $(shell date)"\t"Plotting contig statistics"\n" >> ${DATENAME}.makelog
	Rscript ./bin/FinalizeContigStats.R \
		-l ${PSTAT}/ContigLength.tsv \
		-c ${PSTAT}/FinalContigCounts.tsv \
		-x ${PSTAT}/circularcontigsFormat.tsv
###


### DRAW PRIMARY NETWORK GRAPH (PHAGE + REFERENCE BACTERA)

VREF=./data/ViromeAgainstReferenceBacteria
# In this case the samples will get run against the bacteria reference genome set
ViromeRefRun : ${VREF}/BenchmarkCrisprsFormat.tsv \
	${VREF}/BenchmarkProphagesFormatFlip.tsv \
	${VREF}/MatchesByBlastxFormatOrder.tsv \
	${VREF}/PfamInteractionsFormatScoredFlip.tsv

${VREF}/BenchmarkCrisprsFormat.tsv \
${VREF}/BenchmarkProphagesFormatFlip.tsv \
${VREF}/MatchesByBlastxFormatOrder.tsv \
${VREF}/PfamInteractionsFormatScoredFlip.tsv : \
			./data/TotalCatContigsPhage.fa \
			./data/TotalCatContigsBacteria.fa \
			./bin/BenchmarkingModel.sh
	echo $(shell date)"\t"Calculating predictive values for experimental datasets"\n" >> ${DATENAME}.makelog
	bash ./bin/BenchmarkingModel.sh \
		./data/TotalCatContigsPhage.fa \
		./data/TotalCatContigsBacteria.fa \
		${VREF}/BenchmarkCrisprsFormat.tsv \
		${VREF}/BenchmarkProphagesFormatFlip.tsv \
		${VREF}/MatchesByBlastxFormatOrder.tsv \
		${VREF}/PfamInteractionsFormatScoredFlip.tsv \
		"ViromeAgainstReferenceBacteria"

# Annotate contig IDs with cluster IDs and further compress
clusterrun : ${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
	${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
	${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv

${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv : \
			${VREF}/BenchmarkProphagesFormatFlip.tsv \
			${VREF}/MatchesByBlastxFormatOrder.tsv \
			${VREF}/PfamInteractionsFormatScoredFlip.tsv \
			./data/ContigClustersBacteria/clustering_gt1000.csv \
			./data/ContigClustersPhage/clustering_gt1000.csv \
			./bin/ClusterContigScores.sh
	echo $(shell date)"\t"Collapsing predictive scores by contig clusters"\n" >> ${DATENAME}.makelog
	bash ./bin/ClusterContigScores.sh \
		${VREF}/BenchmarkProphagesFormatFlip.tsv \
		${VREF}/MatchesByBlastxFormatOrder.tsv \
		${VREF}/PfamInteractionsFormatScoredFlip.tsv \
		${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
		${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
		${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv \
		./data/ContigClustersPhage/clustering_gt1000.csv \
		./data/ContigClustersBacteria/clustering_gt1000.csv \
		"ViromeAgainstReferenceBacteria"

# Make a graph database from the experimental information
expnetwork : \
			${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
			${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv \
			${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
			./bin/CreateProteinNetwork
	# Note that this resets the graph database and erases
	# the validation information we previously added.
	echo $(shell date)"\t"Building network using experimental dataset predictive values"\n" >> ${DATENAME}.makelog
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork \
		${VALDIR}/Interactions.tsv \
		${VREF}/BenchmarkCrisprsFormat.tsv \
		${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
		${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv \
		${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
		"FALSE"

# Predict interactions between nodes
./data/PredictedRelationshipTable.tsv : \
			expnetwork \
			./data/rfinteractionmodel.RData \
			./bin/RunPredictionsWithNeo4j.sh
	echo $(shell date)"\t"Predicting interactions between study bacteria and phages"\n" >> ${DATENAME}.makelog
	bash ./bin/RunPredictionsWithNeo4j.sh \
		./data/rfinteractionmodel.RData \
		./data/PredictedRelationshipTable.tsv

# Add relationships
finalrelationships \
./figures/BacteriaPhageNetworkDiagram.pdf \
./figures/BacteriaPhageNetworkDiagram.png \
./figures/PhageHostHist.pdf \
./figures/PhageHostHist.png \
./figures/BacteriaEdgeCount.pdf \
./figures/BacteriaEdgeCount.png : \
		./data/PredictedRelationshipTable.tsv \
		./bin/AddRelationshipsWrapper.sh
	echo $(shell date)"\t"Adding relationships to network and plotting total graph"\n" >> ${DATENAME}.makelog
	bash ./bin/AddRelationshipsWrapper.sh \
		./data/PredictedRelationshipTable.tsv

# Collapse sequence counts by contig cluster
./data/ContigRelAbundForGraphClusteredPhage.tsv \
./data/ContigRelAbundForGraphClusteredBacteria.tsv : \
			./data/ContigClustersPhage/clustering_gt1000.csv \
			./data/ContigClustersBacteria/clustering_gt1000.csv \
			./data/PhageContigAbundance.tsv \
			./data/BacteriaContigAbundance.tsv \
			./bin/ClusterContigAbundance.sh
	echo $(shell date)"\t"Collapsing contig counts by sequence cluster"\n" >> ${DATENAME}.makelog
	bash ./bin/ClusterContigAbundance.sh \
		./data/ContigClustersPhage/clustering_gt1000.csv \
		./data/ContigClustersBacteria/clustering_gt1000.csv \
		./data/PhageContigAbundance.tsv \
		./data/BacteriaContigAbundance.tsv \
		./data/ContigRelAbundForGraphClusteredPhage.tsv \
		./data/ContigRelAbundForGraphClusteredBacteria.tsv


# Add metadata to the graph
addmetadata : \
			./data/ContigRelAbundForGraphClusteredPhage.tsv \
			./data/ContigRelAbundForGraphClusteredBacteria.tsv \
			./data/PublishedDatasets/metadatatable.tsv \
			./bin/AddMetadata.sh
	echo $(shell date)"\t"Adding metadata to interaction network"\n" >> ${DATENAME}.makelog
	bash ./bin/AddMetadata.sh \
		./data/ContigRelAbundForGraphClusteredPhage.tsv \
		./data/ContigRelAbundForGraphClusteredBacteria.tsv \
		./data/PublishedDatasets/metadatatable.tsv
###


################
# Run Analysis #
################
# Get the general properties of the graph per study
./figures/BacteriaPhageNetworkDiagramByStudy.pdf : addmetadata ./bin/VisGraphByGroup.R
	../../bin/neo4j-enterprise-2.3.0/bin/neo4j start
	echo $(shell date)"\t"Plotting subgraphs by study group ID"\n" >> ${DATENAME}.makelog
	Rscript ./bin/VisGraphByGroup.R
	../../bin/neo4j-enterprise-2.3.0/bin/neo4j stop
