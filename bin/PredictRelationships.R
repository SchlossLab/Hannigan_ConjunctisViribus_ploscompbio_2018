#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################################
# Install Dependencies if Needed #
##################################
packagelist <- c("RNeo4j", "ggplot2", "optparse", "caret", "wesanderson", "plotROC")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(packagelist, library, character.only = TRUE)

option_list <- list(
  make_option(c("-m", "--input"),
    type = "character",
    default = NULL,
    help = "Contig count table formatted from bowtie2.",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

###################
# Set Subroutines #
###################
getresults <- function(x) {
  x[is.na(x)] <- 0
  x[x == "TRUE"] <- 1
  x[,3:6] <- as.data.frame(sapply(x[,3:6], as.numeric))
  x <- x[,-c(1:2)]
  rownames(x) <- NULL
  return(x)
}

################
# Run Analysis #
################
# Load in R data file that contains predictive model
load(opt$input)

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

queryresults <- "
MATCH (n)-[r]->(m)
RETURN
m.Name as Bacteria,
n.Name as Phage,
r.CRISPR as CRISPR,
r.BLAST as Blast,
r.BLASTX as Blastx,
r.PFAM as Pfam;
"

# Run the cypher queries
querydata <- cypher(graph, queryresults)

datadef <- getresults(querydata)

comdf <- data.frame(datadef[complete.cases(datadef),])

predoutput <- predict(outmodel$finalModel, newdata=comdf, type = c("class"))

predoutput
