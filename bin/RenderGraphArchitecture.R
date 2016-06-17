library("igraph")
library("visNetwork")
library("RNeo4j")
library("scales")
library("plyr")
library("ndtv")
library("intergraph")

importgraphtodataframe <- function (
graphconnection=graph,
cypherquery=query,
filter=0) {
  write("Retrieving Cypher Query Results", stderr())
  # Use cypher to get the edges
  edges <- cypher(graphconnection, cypherquery)
  nodes <- cypher(graphconnection, qnodes)
  # Filter out nodes with fewer edges than specified
  if (filter > 0) {
    # Remove the edges to singleton nodes
    singlenodes <- ddply(edges, c("to"), summarize, length=length(to))
    # Subset because the it is not visible with all small clusters
    singlenodesremoved <- singlenodes[c(singlenodes$length > filter),]
    multipleedge <- edges[c(which(edges$to %in% singlenodesremoved$to)),]
  } else {
    multipleedge <- edges[,c(1:2)]
  }
  return(list(nodes, multipleedge))
}

plotnetwork <- function (nodeframe=nodeout, edgeframe=edgeout, clusters=FALSE) {
  write("Preparing Data for Plotting", stderr())
  # Pull out the data for clustering
  ig <- graph_from_data_frame(edgeframe, directed=F)
  ig <- asNetwork(ig)
  write("Plotting Network", stderr())
  ig %v% "vertex.properties" <- c(apply(nodeframe[2], 1, function(x) gsub(", ","  ---  ", toString(unlist(x)), perl = TRUE)))[-7]

  sink(file="../data/GraphArchitecture/GraphArchitecture.html")
  render.d3movie(
  	ig, 
  	usearrows = T,
  	displaylabels = T,
  	bg = "White",
  	edge.lwd = 2,
  	edge.length = 4,
  	vertex.cex = 4,
  	vertex.border = "#ffffff",
  	edge.col = '#55555599',
  	vertex.col = "tomato",
  	vertex.tooltip = (ig %v% "vertex.properties"),
  	launchBrowser=F,
    output.mode='inline'
  )
  sink()
}

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
query <- "
START n=node(*) MATCH (n)-[r]->(m) RETURN n.type AS from, m.type AS to, keys(n) as ATT;
"

qnodes <- "
START n=node(*) MATCH (n) RETURN n.type AS node, keys(n) as ATT;
"

graphoutputlist <- importgraphtodataframe()
nodeout <- as.data.frame(graphoutputlist[1])
edgeout <- as.data.frame(graphoutputlist[2])
head(nodeout)
head(edgeout)

plotnetwork()
