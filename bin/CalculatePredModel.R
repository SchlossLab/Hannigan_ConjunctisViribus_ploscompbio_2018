#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################################
# Install Dependencies if Needed #
##################################
list.of.packages <- c("RNeo4j", "ggplot2", "C50")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

#################
# Set Libraries #
#################
suppressMessages(c(
library("RNeo4j"),
library("ggplot2"),
library("C50")
))

###################
# Set Subroutines #
###################
getresults <- function(x, direction=TRUE) {
  x[is.na(x)] <- 0
  x[x == "TRUE"] <- 1
  x[,3:7] <- as.data.frame(sapply(x[,3:7], as.numeric))
  x <- x[,-c(1:2)]
  rownames(x) <- NULL
  return(x)
}

c50model <- function(x, trialcount=10, percentsplit=0.5) {
  x <- x[sample(nrow(x)),]
  # Note this assumes the first column is the category
  categories <- data.frame(x[,1])
  values <- data.frame(x[,-1])
  trainingcount <- round(nrow(x) * percentsplit)
  totalcount <- nrow(x)
  testingcount <- trainingcount + 1
  traincat <- factor(categories[c(1:trainingcount), ])
  trainvalues <- values[c(1:trainingcount), ]
  testcat <- factor(categories[c(testingcount:totalcount), ])
  testvalues <- values[c(testingcount:totalcount), ]

  # Boost the model
  model <-  C50::C5.0(trainvalues, traincat, trials=trialcount)
  pred <- predict(model, testvalues, type="class")
  accuracy <- sum( pred == testcat ) / length( pred )
  return(as.list(summary( model ), accuracy))
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
m.Name as Bacteria,
n.Name as Phage,
r.Interaction as Interaction,
r.CRISPR as CRISPR,
r.BLAST as Blast,
r.BLASTX as Blastx,
r.PFAM as Pfam;
"

querynegative <- "
MATCH (n)-[r]->(m)
WHERE NOT r.Interaction='1'
RETURN
m.Name as Bacteria,
n.Name as Phage,
r.Interaction as Interaction,
r.CRISPR as CRISPR,
r.BLAST as Blast,
r.BLASTX as Blastx,
r.PFAM as Pfam;
"

# Run the cypher queries
positivequerydata <- cypher(graph, querypositive)
negativequerydata <- cypher(graph, querynegative)

# head(positivequerydata)
# head(negativequerydata)

positivedf <- getresults(positivequerydata)
negativedf <- getresults(negativequerydata, FALSE)

dfbind <- rbind(positivedf, negativedf)
dfbind <- data.frame(dfbind[complete.cases(dfbind),])

c50model(dfbind)
