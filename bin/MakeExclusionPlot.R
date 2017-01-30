#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################################
# Install Dependencies if Needed #
##################################
list.of.packages <- c("RNeo4j", "ggplot2", "wesanderson")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, library, character.only = TRUE)

#################
# Set Libraries #
#################
suppressMessages(c(
library("RNeo4j"),
library("ggplot2"),
library("wesanderson"),
))

###################
# Set Subroutines #
###################
getresults <- function(x) {
  x[is.na(x)] <- 0
  x[x == "TRUE"] <- 1
  x[,3:7] <- as.data.frame(sapply(x[,3:7], as.numeric))
  x <- x[,-c(1:2)]
  rownames(x) <- NULL
  x$Interaction <- factor(ifelse(
    x$Interaction > 0,
    "Interacts",
    "NotInteracts"))
  return(x)
}

createexclusiondataframe <- function (x, y) {
  originallength <- length(x[,1])
  scoredlength <- length(x[ rowSums(x[4:5])!=0, 1])
  excludedlength <- originallength - scoredlength
  df <- data.frame(c(excludedlength, scoredlength), c("Excluded", "Included"), c(y, y))
  colnames(df) <- c("Count", "ExclusionStatus", "InteractionStatus")
  return(df)
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

positivedf <- getresults(positivequerydata)
negativedf <- getresults(negativequerydata)

Exclusiondf <- rbind(
  createexclusiondataframe(positivedf, "Interaction"),
  createexclusiondataframe(negativedf, "NonInteraction")
)

Exclusiondf$ExclusionStatus <- factor(Exclusiondf$ExclusionStatus)

excludedgraph <- ggplot(Exclusiondf[order(Exclusiondf$ExclusionStatus, decreasing = TRUE),],
    aes(
      x = factor(InteractionStatus),
      y = Count,
      fill = factor(ExclusionStatus)
    )) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black"),
    legend.position = "top") +
  geom_bar(stat="identity", position="fill") +
  scale_fill_manual(values = wes_palette("Royal1")[c(2,1)], name = "") +
  xlab("Interaction Status") +
  ylab("Percent of Total Samples")

# Save the model to a file so that it can be used later
save(excludedgraph, file="./data/exclusionplot.RData")
