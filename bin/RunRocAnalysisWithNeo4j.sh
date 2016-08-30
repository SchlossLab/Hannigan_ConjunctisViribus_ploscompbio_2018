#! /bin/bash

# Start neo4j server locally
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j start

Rscript ./bin/CalculateModelSpecSens.R

# Stop local neo4j server
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop
