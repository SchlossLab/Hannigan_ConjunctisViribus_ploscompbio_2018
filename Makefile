# Makefile
# Hannigan-2016-ConjunctisViribus
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

############################################# METADATA ############################################

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

# Some of the study metadata is confusing and I'm just not going to waste time parsing all of this.
# It needs to be touched up manually which I loathe, but I will include the file for download.

########################################## SET VARIABLES ##########################################

###########################
# Study Accession Numbers #
###########################
ACCLIST := $(shell awk '{ print "data/ViromePublications/"$$7 }' ./data/PublishedDatasets/SutdyInformation.tsv)

##################
# Sample SRA IDs # 
##################
SRALIST := $(shell awk '{ print $$3 }' ./data/PublishedDatasets/metadatatable.tsv \
	| sort \
	| uniq \
	| sed 's/$$/.sra/' \
	| sed 's/^/data\/ViromePublications\//')

movefiles: ${SRALIST}

###########################
# Sample List for Quality #
###########################
SAMPLELIST := $(shell awk '{ print $$16 }' ./data/PublishedDatasets/metadatatable.tsv \
	| sort \
	| uniq \
	| grep -v "Run" \
	| sed 's/$$/_megahit/' \
	| sed 's/^/data\/QualityOutput\//')

contigs: ${SAMPLELIST}

###############
# Date Record #
###############
DATENAME := $(shell date | sed 's/ /_/g' | sed 's/\:/\./g')

##################################### CREATE & VALIDATE MODEL #####################################

##############################
# Get Study Sequence ID List #
##############################
VALDIR=./data/ValidationSet

${VALDIR}/ValidationPhageNoBlock.fa \
${VALDIR}/ValidationBacteriaNoBlock.fa : \
			${VALDIR}/PhageID.tsv \
			${VALDIR}/BacteriaID.tsv \
			./bin/GetValidationSequences.sh
	echo $(shell date)  :  Downloading validation sequences >> ${DATENAME}.makelog
	bash ./bin/GetValidationSequences.sh \
		${VALDIR}/PhageID.tsv \
		${VALDIR}/BacteriaID.tsv \
		${VALDIR}/ValidationPhageNoBlock.fa \
		${VALDIR}/ValidationBacteriaNoBlock.fa

###########################
# Format Interaction File #
###########################
${VALDIR}/Interactions.tsv : \
			${VALDIR}/BacteriaID.tsv \
			${VALDIR}/InteractionsRaw.tsv \
			./bin/MergeForInteractions.R
	echo $(shell date)  :  Formatting interaction file >> ${DATENAME}.makelog
	Rscript ./bin/MergeForInteractions.R \
		-b ${VALDIR}/BacteriaID.tsv \
		-i ${VALDIR}/InteractionsRaw.tsv \
		-o ${VALDIR}/Interactions.tsv

##############################
# Score For Prediction Model #
##############################
BSET=./data/BenchmarkingSet

${BSET}/BenchmarkCrisprsFormat.tsv \
${BSET}/BenchmarkProphagesFormatFlip.tsv \
${BSET}/MatchesByBlastxFormatOrder.tsv \
${BSET}/PfamInteractionsFormatScoredFlip.tsv : \
			${VALDIR}/ValidationPhageNoBlock.fa \
			${VALDIR}/ValidationBacteriaNoBlock.fa \
			./bin/BenchmarkingModel.sh
	echo $(shell date)  :  Calculating values for interaction predictive model >> ${DATENAME}.makelog
	bash ./bin/BenchmarkingModel.sh \
		${VALDIR}/ValidationPhageNoBlock.fa \
		${VALDIR}/ValidationBacteriaNoBlock.fa \
		${BSET}/BenchmarkCrisprsFormat.tsv \
		${BSET}/BenchmarkProphagesFormatFlip.tsv \
		${BSET}/MatchesByBlastxFormatOrder.tsv \
		${BSET}/PfamInteractionsFormatScoredFlip.tsv \
		"BenchmarkingSet"

###################################
# Build Prediction Graph Database #
###################################
validationnetwork :
	echo $(shell date)  :  Building graph using validation dataset values for prediction >> ${DATENAME}.makelog
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork \
		${VALDIR}/Interactions.tsv \
		${BSET}/BenchmarkCrisprsFormat.tsv \
		${BSET}/BenchmarkProphagesFormatFlip.tsv \
		${BSET}/PfamInteractionsFormatScoredFlip.tsv \
		${BSET}/MatchesByBlastxFormatOrder.tsv \
		"TRUE"

##################################
# Save And Plot Prediction Model #
##################################
./data/rfinteractionmodel.RData :
	echo $(shell date)  :  Predicting interactions between phages and bacteria in graph >> ${DATENAME}.makelog
	bash ./bin/RunRocAnalysisWithNeo4j.sh

######################################## DOWNLOAD RAW DATA ########################################

# ##########################################
# # Download Global Virome Dataset Studies #
# ##########################################
$(ACCLIST): %: ./data/PublishedDatasets/SutdyInformation.tsv ./bin/DownloadPublishedVirome.sh
	echo $@
	echo $(shell date)  :  Downloading study sample sequences from $@ >> ${DATENAME}.makelog
	bash ./bin/DownloadPublishedVirome.sh \
		$< \
		$@

######################################### CONTIG ASSEMBLY #########################################

###################################
# Move SRA Files To New Directory #
###################################
${SRALIST}: %:
	mv $@ data/ViromePublications/

#######################################
# Quality Filtering & Contig Assembly #
#######################################
${SAMPLELIST}: data/QualityOutput/%_megahit:
	echo $(shell date)  :  Performing QC and contig alignment on sample $@ >> ${DATENAME}.makelog
	qsub ./bin/QcAndContigs.pbs -F '$@ ./data/ViromePublications/ ./data/PublishedDatasets/metadatatable.tsv "QualityOutput"'

#################
# Merge Contigs #
#################
# **WARNING**: This step uses random numbers. Rerunning this will yield different results
# and will likely impact downstream processes. Use with caution.
./data/TotalCatContigsBacteria.fa \
./data/TotalCatContigsPhage.fa \
./data/TotalCatContigs.fa : \
			${SAMPLELIST} \
			./data/PublishedDatasets/metadatatable.tsv \
			./bin/catcontigs.sh
	echo $(shell date)  :  Merging contigs into single file >> ${DATENAME}.makelog
	bash ./bin/catcontigs.sh \
		./data/QualityOutput \
		./data/TotalCatContigsBacteria.fa \
		./data/TotalCatContigsPhage.fa \
		./data/PublishedDatasets/metadatatable.tsv \
		./data/TotalCatContigs.fa

######################################### CONTIG ABUNDANCE ########################################

###############################
# Prepare File Path Variables #
###############################
# Generate a contig relative abundance table
ABUNDLISTBACTERIA := $(shell awk ' $$4 == "SINGLE" && $$10 == "Bacteria" { print $$16 } ' ./data/PublishedDatasets/metadatatable.tsv \
	| sort \
	| uniq \
	| grep -v "Run" \
	| sed 's/$$/.fastq-noheader-forcat/' \
	| sed 's/^/data\/QualityOutput\//')

ABUNDLISTVLP := $(shell awk ' $$4 == "SINGLE" && $$10 == "VLP" { print $$16 } ' ./data/PublishedDatasets/metadatatable.tsv \
	| sort \
	| uniq \
	| grep -v "Run" \
	| sed 's/$$/.fastq-noheader-forcat/' \
	| sed 's/^/data\/QualityOutput\//')

PAIREDABUNDLISTBACTERIA := $(shell awk ' $$4 == "PAIRED" && $$10 == "Bacteria" { print $$16 } ' ./data/PublishedDatasets/metadatatable.tsv \
	| sort \
	| uniq \
	| grep -v "Run" \
	| sed 's/$$/_2.fastq-noheader-forcat/' \
	| sed 's/^/data\/QualityOutput\//')

PAIREDABUNDLISTVLP := $(shell awk ' $$4 == "PAIRED" && $$10 == "VLP" { print $$16 } ' ./data/PublishedDatasets/metadatatable.tsv \
	| sort \
	| uniq \
	| grep -v "Run" \
	| sed 's/$$/_2.fastq-noheader-forcat/' \
	| sed 's/^/data\/QualityOutput\//')

#############################
# Build Reference Databases #
#############################
makereference: ./data/bowtieReference/bowtieReferencephage.1.bt2 ./data/bowtieReference/bowtieReferencebacteria.1.bt2

./data/bowtieReference/bowtieReferencephage.1.bt2 :
	mkdir -p ./data/bowtieReference
	bowtie2-build \
		-q ./data/TotalCatContigsPhage.fa \
		./data/bowtieReference/bowtieReferencephage

./data/bowtieReference/bowtieReferencebacteria.1.bt2 :
	mkdir -p ./data/bowtieReference
	bowtie2-build \
		-q ./data/TotalCatContigsBacteria.fa \
		./data/bowtieReference/bowtieReferencebacteria

##########################
# Align Reads to Contigs #
##########################
aligntocontigs: $(ABUNDLISTBACTERIA) $(ABUNDLISTVLP) $(PAIREDABUNDLISTBACTERIA) $(PAIREDABUNDLISTVLP)

$(ABUNDLISTBACTERIA): data/QualityOutput/%.fastq-noheader-forcat : data/QualityOutput/raw/%.fastq ./data/bowtieReference/bowtieReferencebacteria.1.bt2
	qsub ./bin/CreateContigRelAbundTable.pbs -F './data/bowtieReference/bowtieReferencebacteria $<'

$(ABUNDLISTVLP): data/QualityOutput/%.fastq-noheader-forcat : data/QualityOutput/raw/%.fastq ./data/bowtieReference/bowtieReferencephage.1.bt2
	qsub ./bin/CreateContigRelAbundTable.pbs -F './data/bowtieReference/bowtieReferencephage $<'

$(PAIREDABUNDLISTBACTERIA): data/QualityOutput/%_2.fastq-noheader-forcat : data/QualityOutput/raw/%_2.fastq ./data/bowtieReference/bowtieReferencebacteria.1.bt2
	qsub ./bin/CreateContigRelAbundTable.pbs -F './data/bowtieReference/bowtieReferencebacteria $<'

$(PAIREDABUNDLISTVLP): data/QualityOutput/%_2.fastq-noheader-forcat : data/QualityOutput/raw/%_2.fastq ./data/bowtieReference/bowtieReferencephage.1.bt2
	qsub ./bin/CreateContigRelAbundTable.pbs -F './data/bowtieReference/bowtieReferencephage $<'

#########################
# Final Abundance Table #
#########################
./data/ContigRelAbundForGraph.tsv : data/QualityOutput/raw
	cat data/QualityOutput/raw/*-noheader-forcat > ./data/ContigRelAbundForGraph.tsv

###############################
# Final Split Abundance Table #
###############################
./data/BacteriaContigAbundance.tsv ./data/PhageContigAbundance.tsv :
	echo $(shell date)  :  Split contig abundance table between phage and bacteria >> ${DATENAME}.makelog
	bash ./bin/SepAbundanceTable.sh \
		./data/PublishedDatasets/metadatatable.tsv \
		./data/TotalCatContigsBacteria.fa \
		./data/TotalCatContigsPhage.fa \
		./data/BacteriaContigAbundance.tsv \
		./data/PhageContigAbundance.tsv \
		./data/ContigRelAbundForGraph.tsv

######################################### CLUSTER CONTIGS #########################################

#################################
# Prepare Abundance For CONCOCT #
#################################
# Bacteria
./data/ContigRelAbundForConcoctBacteria.tsv : \
			./data/BacteriaContigAbundance.tsv \
			./bin/ReshapeAlignedAbundance.R
	echo $(shell date)  :  Transforming bacteria abundance table for CONCOCT >> ${DATENAME}.makelog
	Rscript ./bin/ReshapeAlignedAbundance.R \
		-i ./data/BacteriaContigAbundance.tsv \
		-o ./data/ContigRelAbundForConcoctBacteria.tsv \
		-p 0.25
# Phage
./data/ContigRelAbundForConcoctPhage.tsv : \
			./data/PhageContigAbundance.tsv \
			./bin/ReshapeAlignedAbundance.R
	echo $(shell date)  :  Transforming phage abundance table for CONCOCT >> ${DATENAME}.makelog
	Rscript ./bin/ReshapeAlignedAbundance.R \
		-i ./data/PhageContigAbundance.tsv \
		-o ./data/ContigRelAbundForConcoctPhage.tsv \
		-p 0.25

###############
# Run CONCOCT #
###############
# Read length is an approximate average from the studies
# Im skipping total coverage because I don't think it makes sense for this dataset
concoctify : ./data/ContigClustersBacteria/clustering_gt1000.csv ./data/ContigClustersPhage/clustering_gt1000.csv
## Bacteria
./data/ContigClustersBacteria \
./data/ContigClustersBacteria/clustering_gt1000.csv: \
			./data/ContigRelAbundForConcoctBacteria.tsv
	echo $(shell date)  :  Clustering bacterial contigs using CONCOCT >> ${DATENAME}.makelog
	mkdir ./data/ContigClustersBacteria
	concoct \
		--coverage_file ./data/ContigRelAbundForConcoctBacteria.tsv \
		--composition_file ./data/TotalCatContigsBacteria.fa \
		--clusters 500 \
		--kmer_length 4 \
		--length_threshold 1000 \
		--read_length 150 \
		--basename ./data/ContigClustersBacteria/ \
		--no_total_coverage \
		--iterations 25
##Phage
./data/ContigClustersPhage \
./data/ContigClustersPhage/clustering_gt1000.csv : \
			./data/ContigRelAbundForConcoctPhage.tsv
	echo $(shell date)  :  Clustering phage contigs using CONCOCT >> ${DATENAME}.makelog
	mkdir ./data/ContigClustersPhage
	concoct \
		--coverage_file ./data/ContigRelAbundForConcoctPhage.tsv \
		--composition_file ./data/TotalCatContigsPhage.fa \
		--clusters 500 \
		--kmer_length 4 \
		--length_threshold 1000 \
		--read_length 150 \
		--basename ./data/ContigClustersPhage/ \
		--no_total_coverage \
		--iterations 25

####################################### CONTIG SUMMARY STATS ######################################

################################
# Format Data For Contig Stats #
################################
PSTAT=./data/PhageContigStats

# Prepare to plot contig stats like sequencing depth, length, and circularity
# Right now this is only getting length because I don't want a sep script
${PSTAT}/ContigLength.tsv \
${PSTAT}/FinalContigCounts.tsv :
	echo $(shell date)  :  Calculating contig statistics >> ${DATENAME}.makelog
	bash ./bin/contigstats.sh \
		./data/TotalCatContigs.fa \
		./data/ContigRelAbundForGraph.tsv \
		${PSTAT}/ContigLength.tsv \
		${PSTAT}/FinalContigCounts.tsv \
		${PSTAT}/circularcontigsFormat.tsv \
		${PSTAT}

####################
# Run Contig Stats #
####################
./figures/ContigStats.pdf \
./figures/ContigStats.png : \
			${PSTAT}/ContigLength.tsv \
			${PSTAT}/FinalContigCounts.tsv \
			./bin/FinalizeContigStats.R
	echo $(shell date)  :  Plotting contig statistics >> ${DATENAME}.makelog
	Rscript ./bin/FinalizeContigStats.R \
		-l ${PSTAT}/ContigLength.tsv \
		-c ${PSTAT}/FinalContigCounts.tsv

##########################
# Get Length Per Cluster #
##########################
${PSTAT}/ClusterLength.tsv :
	Rscript ./bin/collapseLength.R \
		-i ${PSTAT}/ContigLength.tsv \
		-c ./data/ContigClustersPhage/clustering_gt1000.csv \
		-b ./data/ContigClustersBacteria/clustering_gt1000.csv \
		-o ${PSTAT}/ClusterLength.tsv

######################################### INTERACTION SCORES ########################################

######################
# Score Interactions #
######################
VREF=./data/ViromeAgainstReferenceBacteria

# In this case the samples will get run against the bacteria reference genome set
${VREF}/BenchmarkCrisprsFormat.tsv \
${VREF}/BenchmarkProphagesFormatFlip.tsv \
${VREF}/MatchesByBlastxFormatOrder.tsv \
${VREF}/PfamInteractionsFormatScoredFlip.tsv :
	echo $(shell date)  :  Calculating predictive values for experimental datasets >> ${DATENAME}.makelog
	bash ./bin/BenchmarkingModel.sh \
		./data/TotalCatContigsPhage.fa \
		./data/TotalCatContigsBacteria.fa \
		${VREF}/BenchmarkCrisprsFormat.tsv \
		${VREF}/BenchmarkProphagesFormatFlip.tsv \
		${VREF}/MatchesByBlastxFormatOrder.tsv \
		${VREF}/PfamInteractionsFormatScoredFlip.tsv \
		"ViromeAgainstReferenceBacteria"

#####################################
# Compress Scores by Contig Cluster #
#####################################
clusterrun : ${VREF}/BenchmarkProphagesFormatFlipClustered.tsv

${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv :
	echo $(shell date)  :  Collapsing predictive scores by contig clusters >> ${DATENAME}.makelog
	bash ./bin/ClusterContigScores.sh \
		${VREF}/BenchmarkProphagesFormatFlip.tsv \
		${VREF}/MatchesByBlastxFormatOrder.tsv \
		${VREF}/PfamInteractionsFormatScoredFlip.tsv \
		${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
		${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
		${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv \
		./data/ContigClustersPhage/clustering_gt1000.csv \
		./data/ContigClustersBacteria/clustering_gt1000.csv \
		"ViromeAgainstReferenceBacteria" \
		${VREF}/BenchmarkCrisprsFormat.tsv \
		${VREF}/BenchmarkCrisprsFormatClustered.tsv

############################
# Collapse Sequence Counts #
############################
./data/ContigRelAbundForGraphClusteredPhage.tsv \
./data/ContigRelAbundForGraphClusteredBacteria.tsv :
	echo $(shell date)  :  Collapsing contig counts by sequence cluster >> ${DATENAME}.makelog
	bash ./bin/ClusterContigAbundance.sh \
		./data/ContigClustersPhage/clustering_gt1000.csv \
		./data/ContigClustersBacteria/clustering_gt1000.csv \
		./data/PhageContigAbundance.tsv \
		./data/BacteriaContigAbundance.tsv \
		./data/ContigRelAbundForGraphClusteredPhage.tsv \
		./data/ContigRelAbundForGraphClusteredBacteria.tsv

####################################### MAKE VIROME NETWORK #######################################

#######################
# Build Initial Graph #
#######################
expnetwork :
	# Note that this resets the graph database and erases
	# the validation information we previously added.
	echo $(shell date)  :  Building network using experimental dataset predictive values >> ${DATENAME}.makelog
	rm -r ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	mkdir ../../bin/neo4j-enterprise-2.3.0/data/graph.db/
	bash ./bin/CreateProteinNetwork \
		${VALDIR}/Interactions.tsv \
		${VREF}/BenchmarkCrisprsFormatClustered.tsv \
		${VREF}/BenchmarkProphagesFormatFlipClustered.tsv \
		${VREF}/PfamInteractionsFormatScoredFlipClustered.tsv \
		${VREF}/MatchesByBlastxFormatOrderClustered.tsv \
		"FALSE"

########################
# Predict Interactions #
########################
./data/PredictedRelationshipTable.tsv :
	echo $(shell date)  :  Predicting interactions between study bacteria and phages >> ${DATENAME}.makelog
	bash ./bin/RunPredictionsWithNeo4j.sh \
		./data/rfinteractionmodel.RData \
		./data/PredictedRelationshipTable.tsv

####################
# Add Interactions #
####################
finalrelationships \
./figures/BacteriaPhageNetworkDiagram.pdf \
./figures/BacteriaPhageNetworkDiagram.png \
./figures/PhageHostHist.pdf \
./figures/PhageHostHist.png \
./figures/BacteriaEdgeCount.pdf \
./figures/BacteriaEdgeCount.png : \
		./data/PredictedRelationshipTable.tsv \
		./bin/AddRelationshipsWrapper.sh
	echo $(shell date)  :  Adding relationships to network and plotting total graph >> ${DATENAME}.makelog
	bash ./bin/AddRelationshipsWrapper.sh \
		./data/PredictedRelationshipTable.tsv

################
# Add Metadata #
################
addmetadata :
	echo $(shell date)  :  Adding metadata to interaction network >> ${DATENAME}.makelog
	bash ./bin/AddMetadata.sh \
		./data/ContigRelAbundForGraphClusteredPhage.tsv \
		./data/ContigRelAbundForGraphClusteredBacteria.tsv \
		./data/PublishedDatasets/metadatatable.tsv

#########################################################
# Add Contig Cluster Lengths for Downstream Corrections #
#########################################################
addlengths : ./data/PhageContigStats/ClusterLength.tsv
	bash ./bin/AddLengths.sh \
		./data/PhageContigStats/ClusterLength.tsv

################################## CONTIG CLUSTER IDENTIFICATION ##################################
# Find phages in bacteria OGUs

# Make contig length table
./data/BacteriaContigLength.tsv :
	perl ./bin/ContigLengthTable.pl \
		-i ./data/TotalCatContigsBacteria.fa \
		-o $@

# Get ID for longest contig in each cluster
./data/contigclustersidentity/longestcontigsbacteria.tsv : ./data/BacteriaContigLength.tsv
	mkdir -p ./data/contigclustersidentity
	Rscript ./bin/GetLongestContig.R \
		--input $< \
		--clusters ./data/ContigClustersBacteria/clustering_gt1000.csv \
		--toplength 1 \
		--out $@

# Align bacterial contigs to phage reference
./data/tmpid/bacteria2phage-blastout.tsv : ./data/contigclustersidentity/longestcontigsbacteria.tsv
	mkdir -p ./data/tmpid
	cut -f 1 ./data/contigclustersidentity/longestcontigsbacteria.tsv | \
		tail -n +2 \
		> ./data/tmpid/tmpcontiglist.tsv
	grep -A 1 -f ./data/tmpid/tmpcontiglist.tsv ${fastafile} \
		| egrep -v "\-\-" \
		> ./data/tmpid/bacteria-contigrepset.fa
	/nfs/turbo/schloss-lab/bin/ncbi-blast-2.4.0+/bin/makeblastdb \
		-dbtype nucl \
		-in ./data/reference/PhageReference.fa \
		-out ./data/tmpid/PhageReferenceGenomes
	echo Running blastn...
	/nfs/turbo/schloss-lab/bin/ncbi-blast-2.4.0+/bin/blastn \
    	-query ./data/tmpid/bacteria-contigrepset.fa \
    	-out ./data/tmpid/bacteria2phage-blastout.tsv \
    	-db ./data/tmpid/PhageReferenceGenomes \
    	-evalue 1e-25 \
    	-num_threads 8 \
    	-max_target_seqs 1 \
    	-outfmt 6

# Find bacteria in phage OGUs

# Make contig length table
./data/PhageContigLength.tsv :
	perl ./bin/ContigLengthTable.pl \
		-i ./data/TotalCatContigsPhage.fa \
		-o $@

# Get ID for longest contig in each cluster
./data/contigclustersidentity/longestcontigsphage.tsv : ./data/PhageContigLength.tsv
	mkdir -p ./data/contigclustersidentity
	Rscript ./bin/GetLongestContig.R \
		--input $< \
		--clusters ./data/ContigClustersPhage/clustering_gt1000.csv \
		--toplength 1 \
		--out $@

# Align the contig seqs to the bacterial reference database
./data/contigclustersidentity/PhageRepsetIds.tsv :
	bash ./bin/IdentifyContigs.sh \
		./data/TotalCatContigsPhage.fa \
		./data/reference/BacteriaReference.fa \
		./data/contigclustersidentity/longestcontigsphage.tsv \
		$@ \
		"/nfs/turbo/schloss-lab/bin/ncbi-blast-2.4.0+/bin/"


############################################# ANALYSIS ############################################

################
# Run Analysis #
################
# Get the general properties of the graph per study
./figures/BacteriaPhageNetworkDiagramByStudy.pdf :
	../../bin/neo4j-enterprise-2.3.0/bin/neo4j start
	echo $(shell date)  :  Plotting subgraphs by study group ID >> ${DATENAME}.makelog
	Rscript ./bin/VisGraphByGroup.R
	../../bin/neo4j-enterprise-2.3.0/bin/neo4j stop
