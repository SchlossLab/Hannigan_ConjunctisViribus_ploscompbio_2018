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
START n=node(*) MATCH (n)-[r]->(m) RETURN n.Name AS from, m.Name AS to, type(r) AS type;
"
edges = cypher(graph, query)

# Remove the edges to singleton nodes
SingletonNodes <- ddply(edges, c("to"), summarize, length=length(to))
# Subset because the it is not visible with all small clusters
SingletonNodesRemoved <- SingletonNodes[c(SingletonNodes$length > 5),]
MultipleEdge <- edges[c(which(edges$to %in% SingletonNodesRemoved$to)),]
# MultipleEdge <- edges

# Set nodes
nodes = data.frame(id=unique(c(MultipleEdge$from, MultipleEdge$to)))
nodes$label = nodes$id

# Pull out the data for clustering
ig = graph_from_data_frame(MultipleEdge, directed=F)

V(ig)$label = ifelse(grepl("[Pp]hage", nodes$id), "", nodes$id)
V(ig)$label = ""
V(ig)$color = ifelse(grepl("[Pp]hage", nodes$id), rgb(0,0,1,.75), rgb(1,0,0,.75))
E(ig)$color <- with(edges, 
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

#plot(ig, vertex.size=1.5, edge.arrow.size=.2)

l <- layout.auto(ig)

pdf(file="/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/figures/BacteriaPhageNetworkDiagram.pdf", width=8, height=8)
plot(ig, vertex.size=0.30, edge.arrow.size=.1)
legend('bottomleft', legend=c("Phage", "Bacteria"), pt.bg=c(rgb(0,0,1,.75), rgb(1,0,0,.75)), col='black', pch=21, pt.cex=3, cex=1.5, bty = "n")
legend('bottomright', legend=c("Infects_Literature", "Infects_CRISPR", "Infects_Uniprot", "Infects_Blast", "Infects_Pfam"), col=c(rgb(1,0.25,0.25,.5), rgb(0,0.5,1, 0.5), rgb(0.5,0.5,0,.5), rgb(0.5,0.5,0.5,.15), rgb(0.5,0,0.5,.5)), pch='-', pt.cex=3, cex=1.5, bty = "n")
dev.off()

png(file="/Users/Hannigan/git/Hannigan-2016-ConjunctisViribus/figures/BacteriaPhageNetworkDiagram.png", width=8, height=8, units="in", res=800)
plot(ig, vertex.size=0.30, edge.arrow.size=.1, layout=l)
legend('bottomleft', legend=c("Phage", "Bacteria"), pt.bg=c(rgb(0,0,1,.75), rgb(1,0,0,.75)), col='black', pch=21, pt.cex=3, cex=1.5, bty = "n")
legend('bottomright', legend=c("Infects_Literature", "Infects_CRISPR", "Infects_Uniprot", "Infects_Blast"), col=c(rgb(0.5,0,0.5,.5), rgb(0,0.5,1, 0.5), rgb(0.5,0.5,0,.5), rgb(0.5,0.5,0.5,.15)), pch='-', pt.cex=3, cex=1.5, bty = "n")
dev.off()
