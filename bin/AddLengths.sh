#! /bin/bash

export lengths=$1

echo Length file is ${lengths}

# # Remove proxy env variables before running the perl script
# unset http_proxy https_proxy ftp_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY

# Start neo4j server locally
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j start

echo Running neo4j script...

perl ./bin/length2graph.pl \
	-s ${lengths} \
	|| /mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop

# Stop local neo4j server
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop

echo Cleaning up files...

# rm ./tmpAbundance.tsv
