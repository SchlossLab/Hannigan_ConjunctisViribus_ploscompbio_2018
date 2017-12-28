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
lapply(list.of.packages, library, character.only = TRUE)

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

library(parallel)
library(tidyr)
library(dplyr)

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

nestedcv <- function(x, iterations = 5, split = 0.8) {
  outlist <- lapply(1:iterations, function(i) {
    write(i, stdout())

    trainIndex <- createDataPartition(
      x$Interaction,
      p = split, 
      list = FALSE, 
      times = 1
    )
    
    dftrain <- x[trainIndex,]
    dftest <- x[-trainIndex,]

    # write(summary(dftrain$Interaction), stdout())
    # write(summary(dftest$Interaction), stdout())
    
    outmodel <- caretmodel(dftrain)
    
    x_test <- dftest[,2:5]
    y_test <- dftest[,1]
    
    outpred <- predict(outmodel, x_test, type="prob")
    outpred$pred <- predict(outmodel, x_test)
    outpred$obs <- y_test

    # confusionMatrix(outpred, y_test)
    # postResample(pred = outpred$pred, obs = outpred$obs)
    sumout <- twoClassSummary(outpred, lev = levels(outpred$obs))
    sumroc <- sumout[[1]]
    sumsens <- sumout[[2]]
    sumspec <- sumout[[3]]

    write(c(sumroc, sumsens, sumspec), stdout())

    return(list(sumroc, outpred, sumsens, sumspec))
  })

  # Get the max and min values
  rocpositions <- sapply(outlist,`[`,1)
  maxl <- outlist[[match(max(unlist(rocpositions)), rocpositions)]]
  medl <- outlist[[match(median(unlist(rocpositions)), rocpositions)]]
  minl <- outlist[[match(min(unlist(rocpositions)), rocpositions)]]

  return(c(maxl, medl, minl))
}

nestedcvval <- function(x, iterations = 5, split = 0.8) {
  outlist <- mclapply(1:iterations, mc.cores = 4, function(i) {
    write(i, stdout())

    trainIndex <- createDataPartition(
      x$Interaction,
      p = split, 
      list = FALSE, 
      times = 1
    )
    
    dftrain <- x[trainIndex,]
    dftest <- x[-trainIndex,]

    # write(summary(dftrain$Interaction), stdout())
    # write(summary(dftest$Interaction), stdout())
    
    outmodel <- caretmodel(dftrain)
    
    x_test <- dftest[,2:5]
    y_test <- dftest[,1]
    
    outpred <- predict(outmodel, x_test, type="prob")
    outpred$pred <- predict(outmodel, x_test)
    outpred$obs <- y_test

    # confusionMatrix(outpred, y_test)
    # postResample(pred = outpred$pred, obs = outpred$obs)
    sumout <- twoClassSummary(outpred, lev = levels(outpred$obs))
    sumroc <- sumout[[1]]
    sumsens <- sumout[[2]]
    sumspec <- sumout[[3]]

    return(list(sumroc, sumsens, sumspec))
  })

  finaldf <- data.frame(do.call("rbind", outlist))
  colnames(finaldf) <- c("ROC", "Sens", "Spec")
  return(finaldf)
}

nestedVariance <- function(y, iter = 100) {
  ol <- mclapply(1:iter, mc.cores = 4, function(j) {
    write(paste("Running Iteration ", j), stdout())
    nr <- nestedcv(y, iterations = 5, split = 0.8)
    nauc <- nr[[5]]
    nsens <- nr[[7]]
    nspec <- nr[[8]]
    
    medianResult <- c(nauc, nsens, nspec)
    return(medianResult)
  })
  od <- data.frame(do.call("rbind", ol))
  colnames(od) <- c("AUC", "Sens", "Spec")
  return(od)
}

################
# Run Analysis #
################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
# Needs to have the benchmarking database open here (./data/Databases/benchmark)
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "root")

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

dfbind <- rbind(positivedf, negativedf)
dfbind <- data.frame(dfbind[complete.cases(dfbind),])

# Get the variance of the nested cross validation
nvr <- nestedVariance(dfbind)
gnvr <- gather(nvr)
pnvr <- ggplot(gnvr, aes(x = key, y = value, group = key)) +
  theme_classic() +
  geom_boxplot(fill = wes_palette("Royal1")[c(1:3)]) +
  ylab("Model Value") +
  xlab("Model Metric") +
  geom_hline(yintercept = 0.5, linetype="dotted")
pnvr

# Try looking at the raw iterations
ncval <- nestedcvval(dfbind, iterations = 100)
ncgather <- gather(ncval)
ncgather$value <- as.numeric(ncgather$value)

ncstats <- ncgather %>%
  group_by(key) %>%
  summarize(median = median(value), mean = mean(value)) %>%
  as.data.frame()

ncplot <- ggplot(ncgather, aes(x = key, y = value, group = key)) +
  theme_classic() +
  geom_boxplot(fill = wes_palette("Royal1")[c(1:3)]) +
  ylab("Model Value") +
  xlab("Model Metric") +
  geom_hline(yintercept = 0.5, linetype="dotted")
ncplot

pdf(file="./figures/rfModelVariance.pdf",
height=6,
width=8)
  ncplot
dev.off()

# Look at the variation in AUC over iterations
totalrunl <- lapply(1:25, function(j) {
  write(j, stdout())
  outm <- caretmodel(dfbind)
  aucval <- outm$results[order(outm$results$ROC, decreasing = TRUE)[1],"ROC"]
  sensval <- outm$results[order(outm$results$ROC, decreasing = TRUE)[1],"Sens"]
  specval <- outm$results[order(outm$results$ROC, decreasing = TRUE)[1],"Spec"]
  return(c(j, aucval, sensval, specval))
})
trdf <- as.data.frame(do.call("rbind", totalrunl))
colnames(trdf) <- c("iteration", "ROC", "Sens", "Spec")
trdf <- trdf %>%
  gather(iteration) %>% as.data.frame()
colnames(trdf) <- c("iteration", "key", "value")
# Visualize the iteration variation here too
trg <- ggplot(trdf, aes(x = iteration, y = value, group = key, colour = key)) +
  theme_classic() +
  geom_line() +
  ylim(0,1) +
  ylab("Metric Value") +
  xlab("Random Iteration") +
  geom_hline(yintercept = 0.5, linetype="dotted")
trg

pdf(file="./figures/rfIterationVariance.pdf",
height=6,
width=8)
  trg
dev.off()

trdf %>%
  group_by(key) %>%
  summarize(mean = mean(value))

# Do not use even numbers here
nestedresult <- nestedcv(dfbind, iterations = 25, split = 0.80)
# Format for plotting
nestmax <- nestedresult[[2]]
nestmax$class <- "max"
nestmedian <- nestedresult[[6]]
nestmedian$class <- "median"
nestmin <- nestedresult[[10]]
nestmin$class <- "min"
nestmerge <- rbind(nestmax, nestmedian, nestmin)
nestauc <- nestedresult[[5]]
nestsens <- nestedresult[[7]]
nestspec <- nestedresult[[8]]

c(nestauc, nestsens, nestspec)

avgaucplot <- ggplot(nestmerge, aes(d = obs, m = NotInteracts, color = factor(class))) +
  geom_roc(n.cuts = 0, alpha.line = 1.0) +
  style_roc() +
  scale_color_manual(values = c("lightsalmon", "red4", "lightsalmon")) +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black"),
    legend.position = "none"
  ) +
  geom_segment(aes(x = 0, y = 0, xend = 1, yend = 1), linetype=2, colour=wes_palette("Royal1")[1])

avgaucplot


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

# Get the variable importance
vardf <- data.frame(varImp(outmodel$finalModel))
vardf$categories <- rownames(vardf)

vardf <- vardf[order(vardf$Overall, decreasing = TRUE),]
vardf$categories <- factor(vardf$categories, levels = vardf$categories)

importanceplot <- ggplot(vardf, aes(x=categories, y=Overall)) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black")
  ) +
  geom_bar(stat="identity", fill=wes_palette("Royal1")[1]) +
  xlab("Categories") +
  ylab("Importance Score")


# Save the model to a file so that it can be used later
save(avgaucplot, excludedgraph, importanceplot, file="./data/figure1data.RData")
# load(file="./data/rfinteractionmodel.RData")

#############
# Plot Data #
#############
roclobster <- ggplot(outpred, aes(d = obs, m = NotInteracts)) +
  geom_roc(n.cuts = 0, color = wes_palette("Royal1")[2]) +
  style_roc() +
  theme(
    axis.line.x = element_line(colour = "black"),
    axis.line.y = element_line(colour = "black")
  ) +
  geom_segment(aes(x = 0, y = 0, xend = 1, yend = 1), linetype=2, colour=wes_palette("Royal1")[1])

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

barplots <- plot_grid(importanceplot, excludedgraph, labels=c("C", "D"), nrow=1)
horizontal <- plot_grid(rocdensity, barplots, labels=c("B", ""), nrow=2)

# save(roclobster, rocdensity, vardf, importanceplot, file="./data/modelplots.Rdata")
load(file="./data/aucmodel.Rdata")

# save(avgaucplot, file = "./data/aucmodel.Rdata")

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

forprinting <- data.frame(type = c("AUC", "SENS", "SPEC"), result = c(ncstats[1,2], ncstats[2,2], ncstats[3,2]))
write.table(forprinting, file = "./data/avgaucnested.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)
