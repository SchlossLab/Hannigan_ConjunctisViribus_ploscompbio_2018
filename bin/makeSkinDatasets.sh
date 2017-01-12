#! /bin/bash
# makeSkinDatasets.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Set an array with the skin body sites
SKINSITES=(Ax Ac Pa Tw Um Fh Ra Oc)

# Loop through the array with new neo4j instances
for i in "${SKINSITES[@]}"
do
	echo Processing skin site $i
	../../bin/neo4j-enterprise-2.3.0/bin/neo4j start
	Rscript ./bin/GetSkinGraphs.R \
		--location ${i} \
		--timepoint TP3 \
		--output ./data/skingraph-${i}-TP3.Rdata
	../../bin/neo4j-enterprise-2.3.0/bin/neo4j stop
done
