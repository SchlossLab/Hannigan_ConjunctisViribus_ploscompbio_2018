##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)
library("ggraph")

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
    multipleedge <- edges[c(which(edges$to %in% singlenodesremoved$to)),]
  } else {
    multipleedge <- edges
  }
  # Set nodes
  nodes <- data.frame(id=unique(c(multipleedge$from, multipleedge$to)))
  nodes$label <- nodes$id
  return(list(nodes, multipleedge))
}

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
query <- "
MATCH (a)-[]->(x)-[p]->(n)-[r]->(m)<-[q]-(x)
WHERE r.Prediction = 'Interacts'
AND a.Organism = 'StudyID'
AND b.Organism = 'StudyID'
RETURN 
	n.Name AS from,
	m.Name AS to,
	a.Name AS study,
	p.Abundance AS PhageAbund,
	q.Abundance AS BacAbund;
"

graphoutputlist <- importgraphtodataframe()
nodeout <- as.data.frame(graphoutputlist[1])
edgeout <- as.data.frame(graphoutputlist[2])
head(nodeout)
head(edgeout)

# Create subsetted graph
ig <- graph_from_data_frame(edgeout, directed=F)

V(ig)$label <- ifelse(grepl("^Bacteria", nodeout$id),
    "Bacteria",
    "Phage")

outputgraph <- ggraph(ig, 'igraph', algorithm = 'kk') + 
    coord_fixed() + 
    geom_edge_link0(edge_alpha = 0.05) +
    geom_node_point(aes(color = label), size = 1.5) + 
  	facet_wrap(~study) +
    ggforce::theme_no_axes() +
    scale_color_manual(values = wes_palette("Royal1")[c(1,2)])

# Save as PDF & PNG
pdf(file="./figures/BacteriaPhageNetworkDiagramByStudy.pdf",
width=8,
height=8)
  outputgraph
dev.off()
