##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "reshape2")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)
library("ggraph")
library("grid")
library("stringr")

suppressMessages(c(
library("RNeo4j"),
library("ggplot2"),
library("C50"),
library("caret"),
library("wesanderson"),
library("plotROC"),
library("cowplot"),
library("gplots")
))

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

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "root")

# Get number of phages hitting bacteria
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

#################
# Bacteria (to) #
#################

edgecount <- count(edgeout$to)
edgecount <- edgecount[order(edgecount$freq, decreasing=FALSE),]
edgecount$x <- factor(edgecount$x, levels=edgecount$x)

bac_edgeplotgg <- ggplot(edgecount, aes(x=x, y=freq)) +
  theme_classic() +
  theme(axis.line.x = element_line(color="black"),
    axis.line.y = element_line(color="black"),
    axis.text.y=element_blank(),
    axis.ticks.y=element_blank()) +
  geom_bar(stat="identity", fill="tomato3", width = 1) +
  coord_flip() +
  ylab("Count of Phage Predators Per Bacterium") +
  xlab("Bacterial OGUs")

bac_edgeplotgg

################
# Phage (from) #
################

pedgecount <- count(edgeout$from)
pedgecount <- pedgecount[order(pedgecount$freq, decreasing=FALSE),]
pedgecount$x <- factor(pedgecount$x, levels=pedgecount$x)

phage_edgeplotgg <- ggplot(pedgecount, aes(x=x, y=freq)) +
  theme_classic() +
  theme(axis.line.x = element_line(color="black"),
    axis.line.y = element_line(color="black"),
    axis.text.y=element_blank(),
    axis.ticks.y=element_blank()) +
  geom_bar(stat="identity", fill="tomato3", width = 1) +
  coord_flip() +
  ylab("Count of Bacterial Hosts per Phage") +
  xlab("Phage OGUs")

phage_edgeplotgg

mergededge <- plot_grid(bac_edgeplotgg, phage_edgeplotgg, nrow = 1, labels = c("A", "B"))
mergededge

pdf(file="./figures/edgecounts.pdf",
width=8,
height=6)
  mergededge
dev.off()

###########
# Heatmap #
###########
ehit <- edgeout
ehit$hit <- 1
emat <- dcast(ehit, to ~ from)
emat[is.na(emat)] <- 0
emat <- emat[,-1]

pdf(file="./figures/heatedge.pdf",
width=8,
height=6)
  heatmap.2(
		as.matrix(emat),
		trace = "none",
		labRow = "Bacterial OGUs",
		srtRow = 90,
		labCol = "Bacteriophage OGUs",
		srtCol = 0,
		key = FALSE
	)
dev.off()





