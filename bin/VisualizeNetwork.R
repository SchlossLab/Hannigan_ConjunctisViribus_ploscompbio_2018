# VisualizeNetwork.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Load in the needed libraries
library(igraph)
library(visNetwork)
library(RNeo4j)
library(RColorBrewer)
library(scales)
library(plyr)

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph = startGraph("http://localhost:7474/db/data/")

# Use Cypher query to get a table of the table edges
query="
START n=node(*) MATCH (n)-[r]->(m) RETURN n.Name AS from, m.Name AS to;
"
edges = cypher(graph, query)

#test <- as.data.frame(t(as.data.frame(sapply(strsplit(edges[,2], ' '), head,2))))
#edges$to <- paste(test$V1, test$V2, sep=" ")

#colnames(edges) <- c("from","to")

# Remove the edges to singleton nodes
SingletonNodes <- ddply(edges, c("to"), summarize, length=length(to))
# Subset because the it is not visible with all small clusters
SingletonNodesRemoved <- SingletonNodes[c(SingletonNodes$length > 0),]
MultipleEdge <- edges[c(which(edges$to %in% SingletonNodesRemoved$to)),]

# Set nodes
nodes = data.frame(id=unique(c(MultipleEdge$from, MultipleEdge$to)))
nodes$label = nodes$id

# Pull out the data for clustering
ig = graph_from_data_frame(MultipleEdge, directed=F)

V(ig)$label = ifelse(grepl("[Pp]hage", nodes$id), "", nodes$id)
V(ig)$label = ""
V(ig)$color = ifelse(grepl("[Pp]hage", nodes$id), rgb(0,0,1,.75), rgb(1,0,0,.75))
#V(ig)$color <- rgb(0,1,0,.2)
E(ig)$color <- rgb(.5,.5,.5,.2)
E(ig)$width <- 0.01
V(ig)$frame.color <- NA
V(ig)$label.color <- rgb(0,0,.2,.5)

#plot(ig, vertex.size=1.5, edge.arrow.size=.2)

l <- layout.graphopt(ig)

pdf(file="/Users/Hannigan/git/HanniganNotebook/notebook/Figures/2016-01/BacteriaPhageNetworkDiagram.pdf", width=8, height=8)
plot(ig, vertex.size=0.30, edge.arrow.size=.1, layout=l)
dev.off()

