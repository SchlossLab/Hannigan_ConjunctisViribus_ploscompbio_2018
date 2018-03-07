# VisualizeNetwork.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "reshape2")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)
library("ggraph")
library("grid")
library("stringr")

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

importgraphtodataframe <- function (
graphconnection=graph,
cypherquery=query,
filter=0) {
  write("Retrieving Cypher Query Results", stderr())
  # Use cypher to get the edges
  edges <- cypher(graphconnection, cypherquery)
  # Filter out nodes with fewer edges than specified
  if (filter > 0) {
    # Remove the edges to singleton nodes
    singlenodes <- ddply(edges, c("to"), summarize, length=length(to))
    # # Subset because the it is not visible with all small clusters
    # singlenodesremoved <- singlenodes[c(singlenodes$length > filter),]
    multipleedge <- edges[c(which(edges$to %in% singlenodesremoved$to)),]
  } else {
    multipleedge <- edges
  }
  # Set nodes
  nodes <- data.frame(id=unique(c(multipleedge$from, multipleedge$to)))
  nodes$label <- nodes$id
  return(list(nodes, multipleedge))
}

plotnetwork <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Preparing Data for Plotting", stderr())
  # Pull out the data for clustering
  ig <- igraph::graph_from_data_frame(edgeout, directed=F)
  # Set plot paramters
  igraph::V(ig)$label <- ifelse(grepl("Bacteria", nodeout$id),
    "Bacteria",
    "Phage")
  igraph::V(ig)$type <- ifelse(grepl("Bacteria", nodeout$id),
    TRUE,
    FALSE)
  # Create the plot
  fres <- ggraph(ig, 'igraph', algorithm = 'bipartite') + 
        geom_edge_link0(edge_alpha = 0.0065) +
        geom_node_point(aes(color = label), size = 1.5, show.legend = FALSE) +
        ggforce::theme_no_axes() +
        scale_color_manual(values = wes_palette("Royal1")[c(2,4)]) +
        coord_flip() +
        annotate("text", x = 475, y = 0.85, label = "Phage", size = 6, color = wes_palette("Royal1")[c(4)]) +
        annotate("text", x = 25, y = 0.17, label = "Bacteria", size = 6, color = wes_palette("Royal1")[c(2)]) +
        theme_graph(border = FALSE)

  return(fres)
}

wplotnetwork <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Preparing Data for Plotting", stderr())
  # Pull out the data for clustering
  ig <- igraph::graph_from_data_frame(edgeout, directed=F)
  # Set plot paramters
  igraph::V(ig)$label <- ifelse(grepl("Bacteria", nodeout$id),
    "Bacteria",
    "Phage")
  igraph::V(ig)$type <- ifelse(grepl("Bacteria", nodeout$id),
    TRUE,
    FALSE)
  igraph::V(ig)$weights <- nodeout$avg
  # Create the plot
  fres <- ggraph(ig, 'igraph', algorithm = 'bipartite') + 
        geom_edge_link0(edge_alpha = 0.01) +
        geom_node_point(aes(color = label, size = weights)) +
        ggforce::theme_no_axes() +
        scale_color_manual(values = wes_palette("Royal1")[c(2,4)]) +
        coord_flip() +
        theme(legend.position = "none")

  return(fres)
}

graphDiameter <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Graph Diameter", stderr())  
  # Pull out the data for clustering
  ig <- igraph::graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- igraph::diameter(ig, directed=F)
  radnum <- igraph::radius(ig)
  vert <- igraph::vcount(ig)
  edge <- igraph::ecount(ig)
  finaldf <- t(as.data.frame(c(connectionresult, vert, edge, radnum)))
  rownames(finaldf) <- NULL
  colnames(finaldf) <- c("Diameter", "Vertices", "Edges", "Radius")

  return(finaldf)
}

graphEcc <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Graph Diameter", stderr())  
  # Pull out the data for clustering
  ig <- igraph::graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- igraph::eccentricity(ig)
  
  return(connectionresult)
}

connectionstrength <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Testing Connection Strength", stderr())  
  # Pull out the data for clustering
  ig <- igraph::graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- is.connected(ig, mode="strong")
  if (!connectionresult) {
    connectionresult <- is.connected(ig, mode="weak")
      if (connectionresult) {
      result <- "RESULT: Graph is weakly connected."
    } else {
      result <- "RESULT: Graph is not weakly or strongly connected."
    }
  } else {
    result <- "RESULT: Graph is strongly connected."
  }
  return(result)
}

##############################
# Run Analysis & Save Output #
##############################
filterlist <- read.delim(
  file = "./data/contigclustersidentity/bacterialremoval-clusters-list.tsv",
  header = FALSE)

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "root")

# Use Cypher query to get a table of the table edges
query <- "
MATCH (n)-[r]->(m)
WHERE r.Prediction = 'Interacts'
RETURN n.Name AS from, m.Species AS to;
"

graphoutputlist <- importgraphtodataframe()
nodeout <- as.data.frame(graphoutputlist[1])
edgeout <- as.data.frame(graphoutputlist[2])
# Filter out low confidence edges
edgeout <- edgeout[!c(edgeout$from %in% filterlist$V1),]
nodeout <- nodeout[!c(nodeout$label %in% filterlist$V1),]
head(nodeout)
head(edgeout)

# totalnetwork <- plotnetwork()

# Test connection strength of the network
write(connectionstrength(), stderr())

totalstats <- as.data.frame(graphDiameter())
totalstats$class <- "Total"

totalEcc <- as.data.frame(graphEcc())
totalEcc$class <- "Total"
colnames(totalEcc) <- c("TotalECC", "class")

# Collect some stats for the data table
phagenodes <- length(grep("Phage", nodeout[,1]))
bactnodes <- length(grep("Bacteria", nodeout[,1]))
totaledges <- nrow(unique(edgeout[,c(1,2)]))
nestats <- data.frame(cats = c("PhageNodes", "BacteriaNodes", "Edges"), values = c(phagenodes, bactnodes, totaledges))

# Diet subgraph
query <- "
MATCH
  (x:SRP002424)-->(y)-[d]->(z:Phage)-->(a:Bacterial_Host)<-[e]-(b),
  (b)<--(i:PatientID)-->(y),
  (b)<--(t:TimePoint)-->(y),
  (k:Disease)-->(y)
WHERE toInt(d.Abundance) > 0
OR toInt(e.Abundance) > 0
RETURN DISTINCT
  z.Name AS from,
  a.Name AS to,
  i.Name AS PatientID,
  t.Name AS TimePoint,
  k.Name AS Diet,
  toInt(d.Abundance) AS PhageAbundance,
  toInt(e.Abundance) AS BacteriaAbundance;
"

graphoutputlist <- importgraphtodataframe()
nodeout <- as.data.frame(graphoutputlist[1])
edgeout <- as.data.frame(graphoutputlist[2])
# Filter out low confidence edges
edgeout <- edgeout[!c(edgeout$from %in% filterlist$V1),]
nodeout <- nodeout[!c(nodeout$label %in% filterlist$V1),]
# nodeout$order <- str_pad(row.names(nodeout), 4, pad = 0)
# pabund <- ddply(edgeout[,c(1,6)], "from", summarize, avg = median(PhageAbundance))
# babund <- ddply(edgeout[,c(2,7)], "to", summarize, avg = median(BacteriaAbundance))
# colnames(babund) <- c("from", "avg")
# rabund <- rbind(pabund, babund)
# nodeout <- merge(nodeout, rabund, by.x = "label", by.y = "from")
# nodeout <- nodeout[c(order(nodeout$order)),]
head(nodeout)
head(edgeout)
dietphagenodes <- length(grep("Phage", nodeout[,1]))
dietbactnodes <- length(grep("Bacteria", nodeout[,1]))
dedges <- nrow(unique(edgeout[,c(1,2)]))
dietnestats <- data.frame(phagenodes = dietphagenodes, bacterianodes = dietbactnodes, class = "diet", edgecount = dedges)

dietstats <- as.data.frame(graphDiameter())
dietstats$class <- "DietStudy"

DietEcc <- as.data.frame(graphEcc())
DietEcc$class <- "DietStudy"
colnames(DietEcc) <- c("TotalECC", "class")

# dietnetwork <- plotnetwork()

# Twin subgraph
query <- "
MATCH
  (x:SRP002523)-->(y)-[d]->(z:Phage)-->(a:Bacterial_Host)<-[e]-(b),
  (b)<--(i:PatientID)-->(y),
  (b)<--(t:TimePoint)-->(y),
  (k:Disease)-->(y)
WHERE toInt(d.Abundance) > 0
OR toInt(e.Abundance) > 0
RETURN DISTINCT
  z.Name AS from,
  a.Name AS to,
  i.Name AS PatientID,
  t.Name AS TimePoint,
  k.Name AS Diet,
  toInt(d.Abundance) AS PhageAbundance,
  toInt(e.Abundance) AS BacteriaAbundance;
"

graphoutputlist <- importgraphtodataframe()
nodeout <- as.data.frame(graphoutputlist[1])
edgeout <- as.data.frame(graphoutputlist[2])
# Filter out low confidence edges
edgeout <- edgeout[!c(edgeout$from %in% filterlist$V1),]
nodeout <- nodeout[!c(nodeout$label %in% filterlist$V1),]
# nodeout$order <- str_pad(row.names(nodeout), 4, pad = 0)
# pabund <- ddply(edgeout[,c(1,6)], "from", summarize, avg = median(PhageAbundance))
# babund <- ddply(edgeout[,c(2,7)], "to", summarize, avg = median(BacteriaAbundance))
# colnames(babund) <- c("from", "avg")
# rabund <- rbind(pabund, babund)
# nodeout <- merge(nodeout, rabund, by.x = "label", by.y = "from")
# nodeout <- nodeout[c(order(nodeout$order)),]
head(nodeout)
head(edgeout)

twinphagenodes <- length(grep("Phage", nodeout[,1]))
twinbactnodes <- length(grep("Bacteria", nodeout[,1]))
tedges <- nrow(unique(edgeout[,c(1,2)]))
twinnestats <- data.frame(phagenodes = twinphagenodes, bacterianodes = twinbactnodes, class = "twin", edgecount = tedges)

twinstats <- as.data.frame(graphDiameter())
twinstats$class <- "TwinStudy"

TwinEcc <- as.data.frame(graphEcc())
TwinEcc$class <- "TwinStudy"
colnames(TwinEcc) <- c("TotalECC", "class")

# twinnetwork <- plotnetwork()

# Skin subgraph
# Import graphs into a list
skinsites <- c("Ax", "Ac", "Pa", "Tw", "Um", "Fh", "Ra")
# Start list
graphdf <- data.frame()

for (i in skinsites) {
  print(i)
  filename <- paste("./data/skingraph-", i, ".Rdata", sep = "")
  load(file = filename)
  graphdf <- rbind(graphdf, sampletable)
  rm(sampletable)
}

rm(i)

edgeout <- unique(graphdf[c(1:2)])

# Filter out low confidence edges
edgeout <- edgeout[!c(edgeout$from %in% filterlist$V1),]
nodeout <- nodeout[!c(nodeout$label %in% filterlist$V1),]

nodeout <- data.frame(id=unique(c(edgeout$from, edgeout$to)))
nodeout$label <- nodeout$id

# nodeout$order <- str_pad(row.names(nodeout), 4, pad = 0)
# pabund <- ddply(edgeout[,c(1,6)], "from", summarize, avg = median(PhageAbundance))
# babund <- ddply(edgeout[,c(2,7)], "to", summarize, avg = median(BacteriaAbundance))
# colnames(babund) <- c("from", "avg")
# rabund <- rbind(pabund, babund)
# nodeout <- merge(nodeout, rabund, by.x = "label", by.y = "from")
# nodeout <- nodeout[c(order(nodeout$order)),]

head(nodeout)
head(edgeout)

skinphagenodes <- length(grep("Phage", nodeout[,1]))
skinbactnodes <- length(grep("Bacteria", nodeout[,1]))
sedges <- nrow(unique(edgeout[,c(1,2)]))
skinnestats <- data.frame(phagenodes = skinphagenodes, bacterianodes = skinbactnodes, class = "skin", edgecount = sedges)

skinstats <- as.data.frame(graphDiameter())
skinstats$class <- "SkinStudy"

SkinEcc <- as.data.frame(graphEcc())
SkinEcc$class <- "SkinStudy"
colnames(SkinEcc) <- c("TotalECC", "class")

allstats <- rbind(totalstats, dietstats, twinstats, skinstats)
mstat <- melt(allstats)

legend <- get_legend(
  ggplot(mstat, aes(x = class, y = value, fill = class, group = class)) +
    theme_classic() +
    geom_bar(stat = "identity") +
    scale_fill_manual(values = wes_palette("Darjeeling"), name = "Study")
  )

so <- c("Total", "SkinStudy", "TwinStudy", "DietStudy")

mstat <- mstat[order(ordered(mstat$class, levels = so), decreasing = TRUE),]
mstat$class <- factor(mstat$class, levels = mstat$class)

counter <- 1
# Get rid of radius please
mstat <- mstat[!c(mstat$variable %in% "Radius"),]
graphlist <- lapply(unique(mstat$variable), function(i) {
  print(counter)
  oplot <- ggplot(mstat[c(mstat$variable %in% i),], aes(x = class, y = value, fill = class, group = class)) +
    theme_classic() +
    geom_bar(stat = "identity") +
    theme(
        axis.line.x = element_line(colour = "black"),
        axis.line.y = element_line(colour = "black"),
        axis.title.y=element_blank(),
        axis.ticks.y=element_blank(),
        legend.position = "none"
    ) +
    scale_fill_manual(values = wes_palette("Darjeeling")) +
    ylab(i) +
    coord_flip()
    if (counter == 1) {
      oplot <- oplot
    } else {
      oplot <- oplot + theme(axis.text.y=element_text(colour = "white"))
    }
  # Double arrow for outer variable scope
  counter <<- counter + 1
  return(oplot)
})

baseplot <- plot_grid(plotlist = graphlist, nrow = 1, labels = LETTERS[5:7])
baseplot
withlegend <- plot_grid(
  baseplot,
  legend,
  nrow = 1,
  rel_widths = c(5, .75))

totalbpstats <- rbind(dietnestats, twinnestats, skinnestats)

write.table(allstats, file = "./rtables/genfigurestats.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)
write.table(nestats, file = "./rtables/nestats.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)
write.table(totalbpstats, file = "./rtables/totalbp.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)

write.table(mstat, file = "./rtables/sitestattable.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)

# ECCENTRICITY HISTOGRAMS
alecc <- rbind(totalEcc, DietEcc, TwinEcc, SkinEcc)

eccplot <- ggplot(alecc, aes(x = factor(TotalECC))) +
  theme_classic() +
  geom_histogram(stat = "count") +
  xlab("Node Eccentricity") +
  ylab("Frequency") +
  facet_grid(class ~ ., scale = "free")

############# Add Prediction Model Stats #############
load(file="./data/figure1data.RData")

plothorz <- plot_grid(importanceplot, excludedgraph, ncol = 1, labels = c("B", "C"))
wroc <- plot_grid(avgaucplot, plothorz, ncol = 2, labels = c("A"), rel_widths = c(2,1))
baseplot <- plot_grid(plotlist = graphlist, nrow = 1, labels = LETTERS[4:6])
finalp <- plot_grid(wroc, baseplot, ncol = 1, rel_heights = c(2, 1))

pdf(file="./figures/rocCurves.pdf",
width=9,
height=10)
  finalp
dev.off()

pdf(file="./figures/eccplot.pdf",
width=7,
height=7)
  eccplot
dev.off()

modelper <- outmodel$results[(order(outmodel$results$ROC, decreasing = TRUE)),][1,]
write.table(modelper, file = "./rtables/genmodelper.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)
