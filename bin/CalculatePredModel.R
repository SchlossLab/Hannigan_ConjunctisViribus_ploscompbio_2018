#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################################
# Install Dependencies if Needed #
##################################
list.of.packages <- c("RNeo4j", "ggplot2", "C50", "caret", "wesanderson", "plotROC")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

#################
# Set Libraries #
#################
suppressMessages(c(
library("RNeo4j"),
library("ggplot2"),
library("C50"),
library("caret"),
library("wesanderson"),
library("plotROC"),
library("cowplot")
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
  # Convert blastn to factor
  # x$Blast <- factor(ifelse(
  #   x$Blast > 0,
  #   "TRUE",
  #   "FALSE"))
  x$Interaction <- factor(ifelse(
    x$Interaction > 0,
    "Interacts",
    "NotInteracts"))
  return(x)
}

caretmodel <- function(x) {
  x <- x[ rowSums(x[4:5])!=0, ] 
  fitControl <- trainControl(method = "repeatedcv",
                           number = 5,
                           repeats = 10,
                           classProbs = TRUE,
                           summaryFunction = twoClassSummary,
                           savePredictions = TRUE)
  model <- train(Interaction~., data=x, trControl=fitControl, method="rf", metric="ROC")
  return(model)
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
negativedf <- getresults(negativequerydata, FALSE)

dfbind <- rbind(positivedf, negativedf)
dfbind <- data.frame(dfbind[complete.cases(dfbind),])

outmodel <- caretmodel(dfbind)
outmodel

Exclusiondf <- rbind(
  createexclusiondataframe(positivedf, "Interaction"),
  createexclusiondataframe(negativedf, "NonInteraction")
)

Exclusiondf$ExclusionStatus <- factor(Exclusiondf$ExclusionStatus)

excludedgraph <- ggplot(Exclusiondf[order(Exclusiondf$ExclusionStatus, decreasing = TRUE),], aes(x=factor(InteractionStatus), y=Count, fill=factor(ExclusionStatus))) +
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
save(outmodel, "./data/rfinteractionmodel.RData")

#############
# Plot Data #
#############
roclobster <- ggplot(outmodel$pred, aes(d = obs, m = NotInteracts)) +
  geom_roc(n.cuts = 0, color = wes_palette("Royal1")[2]) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black")
  ) +
  geom_segment(aes(x = 0, y = 0, xend = 1, yend = 1), linetype=2, colour=wes_palette("Royal1")[1]) +
  ylab("Sensitivity") +
  xlab(paste("Inverse Specificity"))

# Plot prediction points
rocdensity <- ggplot(outmodel$pred, aes(x=Interacts, group=obs, fill=obs)) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black"),
    legend.position = "bottom"
    ) +
  geom_density(alpha=0.25) +
  scale_fill_manual(values = wes_palette("Royal1"), name = "Prediction Result") +
  xlab("Predicted Interaction Probability") +
  ylab("Occurrence Density")

# Get the variable importance
vardf <- data.frame(varImp(outmodel$finalModel))
vardf$categories <- rownames(vardf)

importanceplot <- ggplot(vardf, aes(x=categories, y=Overall)) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black")
  ) +
  geom_bar(stat="identity", fill=wes_palette("Royal1")[1]) +
  xlab("Categories") +
  ylab("Importance Score")

barplots <- plot_grid(importanceplot, excludedgraph, labels=c("C", "D"), nrow=1)
horizontal <- plot_grid(rocdensity, barplots, labels=c("B", ""), nrow=2)

pdf(file="./figures/rocCurves.pdf",
height=6,
width=12)
  a <- dev.cur()
  png(file="./figures/rocCurves.png",
  height=6,
  width=12,
  units="in",
  res=800)
    dev.control("enable")
    plot_grid(roclobster, horizontal, labels=c("A", ""), nrow=1)
    dev.copy(which=a)
  dev.off()
dev.off()
