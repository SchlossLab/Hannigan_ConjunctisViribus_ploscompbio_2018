# VisualizeNetwork.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################

setwd("~/git/Hannigan-2016-ConjunctisViribus")

library("igraph")
library("visNetwork")
library("RNeo4j")
library("scales")
library("plyr")
library("ggplot2")

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
    # Subset because the it is not visible with all small clusters
    singlenodesremoved <- singlenodes[c(singlenodes$length > filter),]
    multipleedge <- edges[c(which(edges$to %in% singlenodesremoved$to)),]
  } else {
    multipleedge <- edges
  }
  # Set nodes
  nodes <- data.frame(id=unique(c(multipleedge$from, multipleedge$to)))
  nodes$label <- nodes$id
  return(list(nodes, multipleedge))
}

plotnetwork <- function (nodeframe=nodeout, edgeframe=edgeout, clusters=FALSE) {
  write("Preparing Data for Plotting", stderr())
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
  # Set plot paramters
  V(ig)$label <- ""
  V(ig)$color <- ifelse(grepl("contig_", nodeframe$id),
    rgb(0,0,1,.75),
    rgb(1,0,0,.75))
  # Color edges by type
  E(ig)$color <- rgb(0.25,0.25,0.25,0.5)
  E(ig)$width <- 0.01
  V(ig)$frame.color <- NA
  V(ig)$label.color <- rgb(0,0,.2,.5)
  # Set network plot layout
  l <- layout.fruchterman.reingold(ig)
  # Create the plot
  if (clusters) {
    write("Clustering...", stderr())
    clustering <- walktrap.community(ig)
    modular <- modularity(clustering)
    write(paste("Modularity score is:",modular, sep=" "), stderr())
    write("Plotting Network With Clusters", stderr())
    plot(ig,
      mark.groups=clustering,
      vertex.size=0.30,
      edge.arrow.size=.1,
      layout=l
    )
  } else {
    write("Plotting Network", stderr())
    plot(ig,
      vertex.size=0.30,
      edge.arrow.size=.1,
      layout=l
    )
  }
  # Finish by adding the legends
  legend("bottomleft",
    legend=c("Phage", "Bacteria"),
    pt.bg=c(rgb(0,0,1,.75),
      rgb(1,0,0,.75)),
    col="black",
    pch=21,
    pt.cex=3,
    cex=1.5,
    bty = "n"
  )
}

graphDiameter <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Graph Diameter", stderr())  
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- diameter(ig, directed=F)
  return(connectionresult)
}

connectedscore <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Connected Score", stderr())
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- assortativity_degree(ig, directed=F)
  write(connectionresult, stderr())
}

edgecount <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Graph Diversity", stderr())
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- gsize(ig)
  meandistance <- mean_distance(ig, directed = FALSE)
  degreedist <- mean(degree_distribution(ig, cumulative = TRUE))
  write(connectionresult, stderr())
  write(meandistance, stderr())
  write(degreedist, stderr())
}

connectionstrength <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Testing Connection Strength", stderr())  
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
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

ComparingDiseases <- function (diseasename) {
  query <- paste("START n=node(*) MATCH (y:",diseasename,")-[z:Diseased]->()-[x]->(n)-[r]->(m) WHERE x.Abundance > \"0\" RETURN n.Name AS from, m.Name AS to;", sep="")
  graphoutputlist <- importgraphtodataframe(cypherquery=query, filter=0)
  nodeout <- as.data.frame(graphoutputlist[1])
  edgeout <- as.data.frame(graphoutputlist[2])

  connectedscore(nodeframe=nodeout, edgeframe=edgeout)
  edgecount(nodeframe=nodeout, edgeframe=edgeout)

  plotnetwork(nodeframe=nodeout, edgeframe=edgeout, clusters=FALSE)
}

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
diseasearray <- c("`Crohn's_disease`", "`Household_control`", "`Ulcerative_colitis`")

lapply(diseasearray, function(x) {
  ComparingDiseases(x)
  title(main = x)
})

# Save as PDF & PNG
pdf(file="./figures/BacteriaPhageNetworkDiagramClustered_disease.pdf",
width=8,
height=8)
  a <- dev.cur()
  png(file="./figures/BacteriaPhageNetworkDiagramClustered_disease.png",
  width=8,
  height=8,
  units="in",
  res=800)
    dev.control("enable")
    ComparingDiseases("`Household_control`")
    dev.copy(which=a)
  dev.off()
dev.off()



# graphoutputlist <- importgraphtodataframe(filter=10)
# nodeout <- as.data.frame(graphoutputlist[1])
# edgeout <- as.data.frame(graphoutputlist[2])
# head(nodeout)
# head(edgeout)

# # Test connection strength of the network
# write(connectionstrength(), stderr())
# write(graphDiameter(), stderr())


# # Get number of hosts for each phage as histogram
# edgecount <- count(edgeout$from)
# edgecount <- edgecount[order(edgecount$freq, decreasing=FALSE),]
# edgecount$x <- factor(edgecount$x, levels=edgecount$x)

# edgehist <- ggplot(edgecount, aes(x=freq)) +
#   theme_classic() +
#   theme(axis.line.x = element_line(color="black"),
#     axis.line.y = element_line(color="black")) +
#   geom_histogram(fill="tomato3") +
#   xlab("Phage Host Count (Bacterial Strains)") +
#   ylab("Frequency")

# pdf(file="./figures/PhageHostHist_disease.pdf",
# width=8,
# height=8)
#   a <- dev.cur()
#   png(file="./figures/PhageHostHist_disease.png",
#   width=8,
#   height=8,
#   units="in",
#   res=800)
#     dev.control("enable")
#     edgehist
#     dev.copy(which=a)
#   dev.off()
# dev.off()

# # Get number of phages hitting bacteria
# querygenus <- "
# START n=node(*) MATCH (n)-[r]->(m) RETURN n.Name AS from, m.Species AS to;
# "
# graphoutputlist <- importgraphtodataframe(filter=0, cypherquery=querygenus)
# nodeout <- as.data.frame(graphoutputlist[1])
# edgeout <- as.data.frame(graphoutputlist[2])
# head(nodeout)
# head(edgeout)

# edgecount <- count(edgeout$to)
# edgecount <- edgecount[order(edgecount$freq, decreasing=FALSE),]
# edgecount$x <- factor(edgecount$x, levels=edgecount$x)

# edgeplotgg <- ggplot(edgecount, aes(x=x, y=freq)) +
#   theme_classic() +
#   theme(axis.line.x = element_line(color="black"),
#     axis.line.y = element_line(color="black")) +
#   geom_bar(stat="identity", fill="tomato3") +
#   coord_flip() +
#   ylab("Unweighted Count of Targeted Phage") +
#   xlab("")

# pdf(file="./figures/BacteriaEdgeCount_disease.pdf",
# width=8,
# height=8)
#   a <- dev.cur()
#   png(file="./figures/BacteriaEdgeCount_disease.png",
#   width=8,
#   height=8,
#   units="in",
#   res=800)
#     dev.control("enable")
#     edgeplotgg
#     dev.copy(which=a)
#   dev.off()
# dev.off()
