#! /bin/bash

# Load perl module
module load perl/5.22.1
module load perl-modules/5.22.1
module load R/3.2.3

export samples=$1
export metadata=$2

# # Remove proxy env variables before running the perl script
# unset http_proxy https_proxy ftp_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY

# Start neo4j server locally
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j start

echo Running neo4j script...

perl ./Metadata2graph.pl \
	-s ${samples} \
	-m ${metadata} \
	|| /mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop

# Stop local neo4j server
/mnt/EXT/Schloss-data/bin/neo4j-enterprise-2.3.0/bin/neo4j stop
