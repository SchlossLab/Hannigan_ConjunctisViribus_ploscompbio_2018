# PhageTriadicClosures.R
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
	# Set nodes
	nodes = data.frame(id=unique(c(edges$from, edges$to)))
	nodes$label = nodes$id
	# Remove the duplicate rows
	return(list(nodes, edges))
}

PlotNetwork <- function (nodeFrame=nodeout, edgeFrame=edgeout, clusters=FALSE) {
	write("Preparing Data for Plotting", stderr())	
	# Pull out the data for clustering
	ig = simplify(graph_from_data_frame(edgeFrame, directed=F))
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
MATCH (n)-[]->()<-[]-(k) RETURN DISTINCT n.Name AS from, k.Name AS to LIMIT 50000;
"

GraphOutputList <- ImportGraphToDataframe(filter=0)
nodeout <- as.data.frame(GraphOutputList[1])
edgeout <- as.data.frame(GraphOutputList[2])

head(edgeout)

# Save as PDF
pdf(file="/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/figures/BacteriaTriadicClosures.pdf", width=8, height=8)
	PlotNetwork(clusters=TRUE)
dev.off()

