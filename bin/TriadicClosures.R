# TriadicClosures.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################

library(RNeo4j)
library(igraph)
library(plyr)

###################
# Set Subroutines #
###################

ImportGraphToDataframe <- function (GraphConnection=graph, CypherQuery=query, filter=0) {
	write("Retrieving Cypher Query Results", stderr())
	# Use cypher to get the edges
	edges = cypher(GraphConnection, CypherQuery)
	edges <- edges[!duplicated(edges[1:2]),]
	# Filter out nodes with fewer edges than specified
	if (filter > 0) {
		# Remove the edges to singleton nodes
		SingletonNodes <- ddply(edges, c("to"), summarize, length=length(to))
		# Subset because the it is not visible with all small clusters
		SingletonNodesRemoved <- SingletonNodes[c(SingletonNodes$length > filter),]
		MultipleEdge <- edges[c(which(edges$to %in% SingletonNodesRemoved$to)),]
	} else {
		MultipleEdge <- edges
	}
	# Set nodes
	nodes = data.frame(id=unique(c(MultipleEdge$from, MultipleEdge$to)))
	nodes$label = nodes$id
	# Remove the duplicate rows
	return(list(nodes, MultipleEdge))
}

PlotNetwork <- function (nodeFrame=nodeout, edgeFrame=edgeout, clusters=FALSE) {
	write("Preparing Data for Plotting", stderr())	
	# Pull out the data for clustering
	ig = graph_from_data_frame(edgeFrame, directed=F)
	# Set plot paramters
	V(ig)$label = ""
	V(ig)$color = rgb(0,0,1,.75)
	# Color edges by type
	E(ig)$color <- rgb(0.5,0.5,0.5,0.75)
	E(ig)$width <- 0.2
	V(ig)$frame.color <- NA
	V(ig)$label.color <- rgb(0,0,.2,.5)
	# Set network plot layout
	l <- layout.auto(ig)
	# Create the plot
	if (clusters) {
		write("Clustering...", stderr())
		clustering = cluster_edge_betweenness(ig)
		write("Plotting Network With Clusters", stderr())
		plot(ig, 
			mark.groups=clustering,
			vertex.size=1.0, 
			edge.arrow.size=.1,
			layout = l
		)
	} else {
		write("Plotting Network", stderr())
		plot(ig, 
			vertex.size=1.0, 
			edge.arrow.size=.1,
			layout = l
		)
	}
}

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph = startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
query="
MATCH (n)<-[r]-(m)-[j]->(k) WHERE has(n.Genus) AND has(k.Genus) RETURN DISTINCT n.Genus AS from, k.Genus AS to LIMIT 5000;
"

GraphOutputList <- ImportGraphToDataframe(filter=0)
nodeout <- as.data.frame(GraphOutputList[1])
edgeout <- as.data.frame(GraphOutputList[2])

head(edgeout)

# Save as PDF
pdf(file="/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/figures/BacteriaTriadicClosures.pdf", width=8, height=8)
	PlotNetwork(clusters=TRUE)
dev.off()

