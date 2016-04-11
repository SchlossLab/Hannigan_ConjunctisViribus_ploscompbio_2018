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
  V(ig)$color <- ifelse(grepl("[Pp]hage", nodeframe$id),
    rgb(0,0,1,.75),
    rgb(1,0,0,.75))
  # Color edges by type
  E(ig)$color <- rgb(0.25,0.25,0.25,0.5)
  E(ig)$width <- 0.01
  V(ig)$frame.color <- NA
  V(ig)$label.color <- rgb(0,0,.2,.5)
  # Set network plot layout
  l <- layout.auto(ig)
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

connectionstrength <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Testing Connection Strength", stderr())  
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=T)
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

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
query <- "
START n=node(*) MATCH (n)-[r]->(m) RETURN n.Name AS from, m.Name AS to;
"

graphoutputlist <- importgraphtodataframe(filter=10)
nodeout <- as.data.frame(graphoutputlist[1])
edgeout <- as.data.frame(graphoutputlist[2])
head(nodeout)
head(edgeout)

# Test connection strength of the network
write(connectionstrength(), stderr())

# Save as PDF & PNG
pdf(file="./figures/BacteriaPhageNetworkDiagramClustered.pdf",
width=8,
height=8)
  a <- dev.cur()
  png(file="./figures/BacteriaPhageNetworkDiagramClustered.png",
  width=8,
  height=8,
  units="in",
  res=800)
    dev.control("enable")
    plotnetwork(clusters=TRUE)
    dev.copy(which=a)
  dev.off()
dev.off()

pdf(file="./figures/BacteriaPhageNetworkDiagram.pdf",
width=8,
height=8)
  a <- dev.cur()
  png(file="./figures/BacteriaPhageNetworkDiagram.png",
  width=8,
  height=8,
  units="in",
  res=800)
    dev.control("enable")
    plotnetwork(clusters=FALSE)
    dev.copy(which=a)
  dev.off()
dev.off()
