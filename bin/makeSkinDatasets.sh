#! /bin/bash
# makeSkinDatasets.sh
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Set an array with the skin body sites
SKINSITES=(Ax Ac Pa Tw Um Fh Ra Oc)
PATIENTS=(\
	skin_1 \
	skin_2 \
	skin_3 \
	skin_4 \
	skin_5 \
	skin_6 \
	skin_7 \
	skin_8 \
	skin_9 \
	skin_10 \
	skin_11 \
	skin_12 \
	skin_13 \
	skin_14 \
	skin_15 \
	skin_16 \
	skin_17 \
	skin_18 \
	skin_19 \
	skin_20)
TIMEPOINTS=(TP2 TP3)

# # Loop through the array with new neo4j instances
# for i in "${SKINSITES[@]}"
# do
# 	echo Processing skin site $i
# 	../../bin/neo4j-enterprise-2.3.0/bin/neo4j start
# 	Rscript ./bin/GetSkinGraphs.R \
# 		--location ${i} \
# 		--timepoint TP2 \
# 		--output ./data/skingraph-${i}.Rdata
# 	../../bin/neo4j-enterprise-2.3.0/bin/neo4j stop
# done

# for i in "${SKINSITES[@]}"
# do
# 	echo Processing skin site $i
# 	../../bin/neo4j-enterprise-2.3.0/bin/neo4j start
# 	Rscript ./bin/GetSkinGraphs.R \
# 		--location ${i} \
# 		--timepoint TP3 \
# 		--output ./data/skingraph-${i}-TP3.Rdata
# 	../../bin/neo4j-enterprise-2.3.0/bin/neo4j stop
# done

# Get the total graphs as well
for i in "${SKINSITES[@]}"
do
	for j in "${PATIENTS[@]}"
	do
		for k in "${TIMEPOINTS[@]}"
		do
			echo Processing skin site $i
			echo Processing patient $j
			echo Processing timepoint $k
			Rscript ./bin/GetSkinGraphs.R \
				--location ${i} \
				--timepoint ${k} \
				--patient ${j} \
				--output ./data/skingraph-${i}-${j}-${k}.Rdata \
				--allconnections
		done
	done
done


