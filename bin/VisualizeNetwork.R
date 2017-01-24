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
  ig <- graph_from_data_frame(edgeframe, directed=F)
  # Set plot paramters
  V(ig)$label <- ifelse(grepl("^Bacteria", nodeframe$id),
    "Bacteria",
    "Phage")
  # Create the plot
  outputgraph <- ggraph(ig, 'igraph', algorithm = 'kk') + 
        coord_fixed() + 
        geom_edge_link0(edge_alpha = 0.05) +
        geom_node_point(aes(color = label), size = 1.5) +
        ggforce::theme_no_axes() +
        scale_color_manual(values = wes_palette("Royal1")[c(1,2)])
  return(outputgraph)
}

graphDiameter <- function (nodeframe=nodeout, edgeframe=edgeout) {
  write("Calculating Graph Diameter", stderr())  
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
  connectionresult <- diameter(ig, directed=F)
  edgecon <- edge_connectivity(ig)
  dcc <- centr_degree(ig)$centralization
  vert <- vcount(ig)
  edge <- ecount(ig)
  finaldf <- t(as.data.frame(c(connectionresult, edgecon, dcc, vert, edge)))
  rownames(finaldf) <- NULL
  colnames(finaldf) <- c("diameter", "econn", "dc", "vert", "edge")

  return(finaldf)
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

##############################
# Run Analysis & Save Output #
##############################

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
head(nodeout)
head(edgeout)

totalnetwork <- plotnetwork()

# Test connection strength of the network
write(connectionstrength(), stderr())

totalstats <- as.data.frame(graphDiameter())
totalstats$class <- "Total"

length(grep("Phage", nodeout[,1]))
length(grep("Bacteria", nodeout[,1]))

length(edgeout[,1])

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
head(nodeout)
head(edgeout)

dietstats <- as.data.frame(graphDiameter())
dietstats$class <- "DietStudy"

dietnetwork <- plotnetwork()

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
head(nodeout)
head(edgeout)

twinstats <- as.data.frame(graphDiameter())
twinstats$class <- "TwinStudy"

twinnetwork <- plotnetwork()

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

nodeout <- data.frame(id=unique(c(edgeout$from, edgeout$to)))
nodeout$label <- nodeout$id

skinstats <- as.data.frame(graphDiameter())
skinstats$class <- "SkinStudy"

allstats <- rbind(totalstats, dietstats, twinstats, skinstats)
mstat <- melt(allstats)

legend <- get_legend(
  ggplot(mstat, aes(x = class, y = value, fill = class, group = class)) +
    theme_classic() +
    geom_bar(stat = "identity") +
    scale_fill_manual(values = wes_palette("Darjeeling"), name = "Study")
  )

graphlist <- lapply(unique(mstat$variable), function(i) {
  ggplot(mstat[c(mstat$variable %in% i),], aes(x = class, y = value, fill = class, group = class)) +
    theme_classic() +
    geom_bar(stat = "identity") +
    theme(
        axis.line.x = element_line(colour = "black"),
        axis.line.y = element_line(colour = "black"),
        axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        legend.position = "none"
    ) +
    scale_fill_manual(values = wes_palette("Darjeeling")) +
    ylab(i)
})

baseplot <- plot_grid(plotlist = graphlist, nrow = 1, labels = LETTERS[5:9])
withlegend <- plot_grid(
  baseplot,
  legend,
  nrow = 1,
  rel_widths = c(5, .75))

skinnetwork <- plotnetwork()

threeplot <- plot_grid(
  dietnetwork,
  twinnetwork,
  skinnetwork,
  ncol = 1,
  labels = c("B", "C", "D"))

almostplot <- plot_grid(totalnetwork, threeplot, ncol = 2, rel_widths = c(2,1), labels = c("A"))

finalplot <- plot_grid(almostplot, withlegend, nrow = 2, rel_heights = c(2,1))

pdf(file="./figures/BacteriaPhageNetworkDiagram.pdf",
width=12,
height=9)
  finalplot
dev.off()
