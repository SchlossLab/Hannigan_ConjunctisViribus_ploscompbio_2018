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
library("pgirmess")

###################
# Set Subroutines #
###################

importgraphtodataframe <- function (
graphconnection=graph,
cypherquery=query,
filter=0) {
  write("Retrieving Cypher Query Results", stderr())
  write(cypherquery, stderr())
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
  E(ig)$color <- rgb(0.25,0.25,0.25,0.75)
  E(ig)$width <- 0.1
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
      vertex.size=0.75,
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
  p <- recordPlot()
  p
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
  connectionresult <- eccentricity(ig)
  return(connectionresult)
}

edgecount <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Graph Diversity", stderr())
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=T)
  connectionresult <- gsize(ig)
  meandistance <- mean_distance(ig, directed = FALSE)
  degreedist <- c(degree_distribution(ig, cumulative = TRUE))
  acent <- c(alpha_centrality(ig))
  pc <- c(power_centrality(ig))
  return(acent)
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
  query <- paste("START n=node(*) MATCH (y:",diseasename,")-[z:Diseased]->()-[x]->(n)-[r]->(m) WHERE x.Abundance > \"1\" RETURN n.Name AS from, m.Name AS to;", sep="")
  graphoutputlist <- importgraphtodataframe(cypherquery=query, filter=0)
  nodeout <- as.data.frame(graphoutputlist[1])
  edgeout <- as.data.frame(graphoutputlist[2])

  connectedscore(nodeframe=nodeout, edgeframe=edgeout)
  edgecount(nodeframe=nodeout, edgeframe=edgeout)

  plotnetwork(nodeframe=nodeout, edgeframe=edgeout, clusters=FALSE)
}

ComparingDiseasesBySample <- function (diseasename) {
  # Get sample names associated with the disease
  queryforsample <- paste("START n=node(*) MATCH (y:",diseasename,")-[z:Diseased]->(a)-[x]->(n)-[r]->(m) RETURN DISTINCT a.Name AS ID;", sep="")
  samplelist <- cypher(graph, queryforsample)

  lapply(samplelist$ID, function(var) {
    query <- paste("START n=node(*) MATCH ()-[z:Diseased]->(x:",var,")-[y]->(n)-[r]->(m) WHERE y.Abundance > \"1\"  RETURN n.Name AS from, m.Name AS to;", sep="")
    
    graphoutputlist <- importgraphtodataframe(cypherquery=query, filter=0)
    nodeout <- as.data.frame(graphoutputlist[1])
    edgeout <- as.data.frame(graphoutputlist[2])

    # return(connectedscore(nodeframe=nodeout, edgeframe=edgeout))
    resultedge <- data.frame(edgecount(nodeframe=nodeout, edgeframe=edgeout))
    resultedge$names <- rownames(resultedge)
    colnames(resultedge) <- c("value", "name")
    resultedge
    # graphDiameter(nodeframe=nodeout, edgeframe=edgeout)

    # plotnetwork(nodeframe=nodeout, edgeframe=edgeout, clusters=FALSE)
  })
}

ComparingDiseases2 <- function (diseasename) {
  query <- paste("START n=node(*) MATCH (y:",diseasename,")-[z:Diseased]->()-[x]->(n)-[r]->(m) WHERE x.Abundance > \"0\" RETURN n.Name AS from, m.Species AS to;", sep="")
  graphoutputlist <- importgraphtodataframe(cypherquery=query, filter=0)
  nodeout <- as.data.frame(graphoutputlist[1])
  edgeout <- as.data.frame(graphoutputlist[2])

  # Get number of hosts for each phage as histogram
  edgecount <- count(edgeout$from)
  edgecount <- edgecount[order(edgecount$freq, decreasing=FALSE),]
  edgecount$x <- factor(edgecount$x, levels=edgecount$x)
  
  edgehist <- ggplot(edgecount, aes(x=freq)) +
    theme_classic() +
    theme(axis.line.x = element_line(color="black"),
      axis.line.y = element_line(color="black")) +
    geom_histogram(fill="tomato3") +
    xlab("Phage Host Count (Bacterial Strains)") +
    ylab("Frequency") +
    ggtitle(diseasename)

  query <- paste("START n=node(*) MATCH (y:",diseasename,")-[z:Diseased]->()-[x]->(n)-[r]->(m) WHERE x.Abundance > \"0\" RETURN n.Name AS from, m.Genus AS to;", sep="")
  graphoutputlist <- importgraphtodataframe(cypherquery=query, filter=0)
  nodeout <- as.data.frame(graphoutputlist[1])
  edgeout <- as.data.frame(graphoutputlist[2])

  edgecount <- count(edgeout$to)
  edgecount <- edgecount[order(edgecount$freq, decreasing=FALSE),]
  edgecount$x <- factor(edgecount$x, levels=edgecount$x)

  edgeplotgg <- ggplot(edgecount, aes(x=x, y=freq)) +
    theme_classic() +
    theme(axis.line.x = element_line(color="black"),
      axis.line.y = element_line(color="black")) +
    geom_bar(stat="identity", fill="tomato3") +
    coord_flip() +
    ylab("Unweighted Count of Targeted Phage") +
    xlab("") +
    ggtitle(diseasename)

  edgehist
  edgeplotgg
}

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
diseasearray <- c("`Crohn's_disease`", "`Household_control`", "`Ulcerative_colitis`")

# resultdf <- do.call("rbind", ComparingDiseasesBySample("Ulcerative_colitis"))
# resultdf[-grep("contig", resultdf$name),]

# pdf(file="./figures/DiseaseSampleCompPlots.pdf",
# width=8,
# height=8)
#   resultdf1 <- do.call("rbind", ComparingDiseasesBySample("Ulcerative_colitis"))
#   resultdf1 <- resultdf1[-grep("contig", resultdf1$name),]
#   resultdf1$cat <- "Ulcerative_colitis"

#   resultdf2 <- do.call("rbind", ComparingDiseasesBySample("Household_control"))
#   resultdf2 <- resultdf2[-grep("contig", resultdf2$name),]
#   resultdf2$cat <- "Household_control"

#   resultdf3 <- do.call("rbind", ComparingDiseasesBySample("`Crohn's_disease`"))
#   resultdf3 <- resultdf3[-grep("contig", resultdf3$name),]
#   resultdf3$cat <- "`Crohn's_disease`"

#   mergeddf <- rbind(resultdf1, resultdf2, resultdf3)

#   ggplot(mergeddf, aes(x=cat, y=value, fill="tomato3")) +
#     theme_classic() +
#     theme(axis.line.x = element_line(color="black"),
#       axis.line.y = element_line(color="black"),
#       legend.position="none") +
#     geom_boxplot(notch=TRUE) +
#     scale_y_log10() +
#     ylab("Bacterial Node Centrality") +
#     xlab("Disease Category")
# dev.off()

# kruskalmc(mergeddf$value, mergeddf$cat)

pdf(file="./figures/tmpDiseaseSampleCompPlots.pdf",
width=8,
height=8)
  # Create one plot for each disease type
  layout(matrix(c(1,2,3), 1, 3, byrow = TRUE))
  lapply(diseasearray, function(x) {
      ComparingDiseases(x)
      title(main = x)
})
dev.off()

png(file="./figures/BacteriaPhageNetworkDiagramByDisease.png",
width=8,
height=4,
units="in",
res=800)
  # Create one plot for each disease type
  layout(matrix(c(1,2,3), 1, 3, byrow = TRUE))
  lapply(diseasearray, function(x) {
      ComparingDiseases(x)
      title(main = x)
})
dev.off()

