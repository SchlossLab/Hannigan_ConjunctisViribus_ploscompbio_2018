#! /bin/bash

export samplesPhage=$1
export sampleBacteria=$2
export metadata=$3

echo Phage sample file is ${samplesPhage}
echo Bacteria sample file is ${sampleBacteria}
echo Metadata file is ${metadata}

# Put together the two abundance files
cat ${samplesPhage} ${sampleBacteria} > ./tmpAbundance.tsv

# # Remove proxy env variables before running the perl script
# unset http_proxy https_proxy ftp_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY

# Start neo4j server locally
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j start

echo Running neo4j script...

perl ./bin/Metadata2graph.pl \
	-s ./tmpAbundance.tsv \
	-m ${metadata} \
	|| /mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop

# Stop local neo4j server
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop

echo Cleaning up files...

# rm ./tmpAbundance.tsv
