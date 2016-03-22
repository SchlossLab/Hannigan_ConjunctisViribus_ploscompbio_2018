# VisualizeNetwork.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################

library(igraph)
library(visNetwork)
library(RNeo4j)
library(scales)
library(plyr)

###################
# Set Subroutines #
###################

ImportGraphToDataframe <- function (GraphConnection=graph, CypherQuery=query, filter=0) {
	# Use cypher to get the edges
	edges = cypher(GraphConnection, CypherQuery)
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
	return(list(nodes, MultipleEdge))
}

PlotNetwork <- function (nodeFrame=nodeout, edgeFrame=edgeout) {
	# Pull out the data for clustering
	ig = graph_from_data_frame(edgeFrame, directed=F)
	# Set plot paramters
	V(ig)$label = ifelse(grepl("[Pp]hage", nodeFrame$id), "", nodeFrame$id)
	V(ig)$color = ifelse(grepl("[Pp]hage", nodeFrame$id), rgb(0,0,1,.75), rgb(1,0,0,.75))
	# Color edges by type
	E(ig)$color <- with(edgeFrame, 
	    ifelse(grepl("Infects_Literature", type), rgb(1,0.25,0.25,0.5),
	    ifelse(grepl("Infects_CRISPR", type), rgb(0,0.5,1, 0.5),
	    ifelse(grepl("Infects_Uniprot", type), rgb(0.5,0.5,0,0.5),
	    ifelse(grepl("Infects_Blast", type), rgb(0.5,0.5,0.5,0.15),
	    ifelse(grepl("Infects_Pfam", type), rgb(0.5,0,0.5,0.5),
	    rgb(1,1,1,0.5)
	))))))
	E(ig)$width <- 0.01
	V(ig)$frame.color <- NA
	V(ig)$label.color <- rgb(0,0,.2,.5)
	# Set network plot layout
	l <- layout.graphopt(ig)
	# Create the plot
	plot(ig, 
		vertex.size=0.30, 
		edge.arrow.size=.1
	)
	legend('bottomleft', 
		legend=c("Phage", "Bacteria"), 
		pt.bg=c(rgb(0,0,1,.75), 
			rgb(1,0,0,.75)), 
		col='black', 
		pch=21, 
		pt.cex=3, 
		cex=1.5, 
		bty = "n"
	)
	legend('bottomright', 
		legend=c("Infects_Literature", 
			"Infects_CRISPR", 
			"Infects_Uniprot", 
			"Infects_Blast", 
			"Infects_Pfam"),
		col=c(rgb(1,0.25,0.25,.5), 
			rgb(0,0.5,1, 0.5), 
			rgb(0.5,0.5,0,.5), 
			rgb(0.5,0.5,0.5,.15), 
			rgb(0.5,0,0.5,.5)), 
		pch='-', 
		pt.cex=3, 
		cex=1.5, 
		bty = "n"
	)
}

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph = startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

# Use Cypher query to get a table of the table edges
query="
START n=node(*) MATCH (n)-[r]->(m) RETURN n.Name AS from, m.Genus AS to, type(r) AS type;
"

GraphOutputList <- ImportGraphToDataframe(filter=200)
nodeout <- as.data.frame(GraphOutputList[1])
edgeout <- as.data.frame(GraphOutputList[2])
head(nodeout)
head(edgeout)

# Save as PDF
pdf(file="/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/figures/BacteriaPhageNetworkDiagram.pdf", width=8, height=8)
	PlotNetwork()
dev.off()
# Save as PNG
png(file="/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/figures/BacteriaPhageNetworkDiagram.png", width=8, height=8, units="in", res=800)
	PlotNetwork()
dev.off()
