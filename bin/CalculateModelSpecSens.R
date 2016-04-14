#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

#################
# Set Libraries #
#################

setwd("~/git/Hannigan-2016-ConjunctisViribus/data/BenchmarkingResults")

suppressMessages(c(
library("igraph"),
library("RNeo4j"),
library("pROC"),
library("ggplot2"),
library("gridExtra"),
library("grid")
))

###################
# Set Subroutines #
###################
getresults <- function(x, direction=TRUE) {
  x[is.na(x)] <- 0
  x[x == "TRUE"] <- 1
  x[,3:6] <- as.data.frame(sapply(x[,3:6], as.numeric))
  x$Prediction <- rowSums(x[,c(4:6)])
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

calculatetfpos <- function(x,y) {
  # Get the frequency rates
  posratedf <- as.data.frame(table(x$Correct))
  posratedf <- as.data.frame(sapply(posratedf, as.numeric))

  negratedf <- as.data.frame(table(y$Correct))
  negratedf <- as.data.frame(sapply(negratedf, as.numeric))

  posrate <- posratedf[2,2] / (posratedf[1,2] + posratedf[2,2])
  negrate <- (negratedf[2,2] / (negratedf[1,2] + negratedf[2,2]))
  return(c(posrate, negrate))
}

roclobster <- function(x,y) {
  combo <- rbind(x,y)
  rocobjt <- roc(Interaction ~ Prediction, combo)
  plot.roc(rocobjt, print.thres=TRUE, print.auc=TRUE)
}

plotheatmap <- function(x,y) {
  singleplot <- function(z, letter) {
    heatmap <- ggplot(z, aes(Bacteria, Phage)) +
      theme_classic() +
      geom_tile(aes(fill=factor(Correct))) +
      scale_fill_brewer(palette="Set1",
        guide = guide_legend(title = "Interactions")) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
      ylab("Bacteria") +
      xlab("Bacteriophages") +
      ggtitle("Bacteriophage - Bacteria Benchmark Interactions")
    # Add letter label to corner
    heatmap <- arrangeGrob(heatmap,
      top = textGrob(letter, x = unit(0, "npc"),
      y = unit(1, "npc"),
      just=c("left","top"),
      gp=gpar(col="black", fontsize=28, fontfamily="Helvetica")))
    return(heatmap)
  }
  grid.arrange(
    singleplot(x, "A"),
    singleplot(y, "B"),
    ncol = 1)
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
r.PFAM as Pfam;
"

# Run the cypher queries
positivequerydata <- cypher(graph, querypositive)
negativequerydata <- cypher(graph, querynegative)

head(positivequerydata)

positivedf <- getresults(positivequerydata)
negativedf <- getresults(negativequerydata, FALSE)

as.data.frame(table(positivedf$Correct))
calculatetfpos(positivedf, negativedf)

###############
# Save Output #
###############

pdf(file="../../figures/rocCurves.pdf",
height=8,
width=8)
  a <- dev.cur()
  png(file="../../figures/rocCurves.png",
  width=8,
  height=8,
  units="in",
  res=800)
    dev.control("enable")
    roclobster(positivedf, negativedf)
    dev.copy(which=a)
  dev.off()
dev.off()

pdf(file="../../figures/ResultHeatmaps.pdf",
height=18,
width=10)
  a <- dev.cur()
  png(file="../../figures/ResultHeatmaps.png",
  width=10,
  height=12,
  units="in",
  res=800)
    dev.control("enable")
    plotheatmap(positivedf, negativedf)
    dev.copy(which=a)
  dev.off()
dev.off()

write.table(positivedf, file="./PositiveHitResults.tsv",
  sep="\t",
  quote=FALSE,
  row.names=FALSE)

write.table(negativedf, file="./NegativeHitResults.tsv",
  sep="\t",
  quote=FALSE,
  row.names=FALSE)
