#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Libraries #
#################

suppressMessages(c(
library("igraph"),
library("RNeo4j")
))

###################
# Set Subroutines #
###################
getresults <- function(x, direction=TRUE) {
  x[is.na(x)] <- 0
  x[x == "TRUE"] <- 1
  x <- as.data.frame(sapply(x, as.numeric))
  x$Prediction <- rowSums(x[,c(2:4)])
  if (direction) {
    x$Correct <- ifelse(
      x$Interaction <= x$Prediction,
      "YES",
      "NO")
  } else {
    x$Correct <- ifelse(
      x$Interaction == x$Prediction,
      "YES",
      "NO")
  }
  return(x)
}

################
# Run Analysis #
################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

querypositive <- "
MATCH (n)-[r]->(m)
WHERE r.Interaction='1'
RETURN
r.Interaction as Interaction,
r.CRISPR as CRISPR,
r.BLAST as Blast,
r.PFAM as Pfam;
"

querynegative <- "
MATCH (n)-[r]->(m)
WHERE NOT r.Interaction='1'
RETURN
r.Interaction as Interaction,
r.CRISPR as CRISPR,
r.BLAST as Blast,
r.PFAM as Pfam;
"

# Run the cypher queries
positivedf <- cypher(graph, querypositive)
negativedf <- cypher(graph, querynegative)

getresults(positivedf)
getresults(negativedf, FALSE)
