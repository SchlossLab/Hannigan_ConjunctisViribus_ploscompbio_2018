# GetSkinGraphs.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "scales", "plyr", "cowplot", "vegan", "reshape2", "optparse")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)

option_list <- list(
  make_option(c("-l", "--location"),
    type = "character",
    default = NULL,
    help = "Skin location for graph.",
    metavar = "character"),
  make_option(c("-t", "--timepoint"),
    type = "character",
    default = NULL,
    help = "The time point to use.",
    metavar = "character"),
  make_option(c("-o", "--output"),
    type = "character",
    default = NULL,
    help = "Output table file.",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

write(paste("Pulling graph for", opt$location, opt$timepoint, sep = "\t"), stderr())

sampleidquery <- paste("
MATCH
	(x:SRP049645)-->(y)-[d]->(z:Phage)-->(a:Bacterial_Host)<-[e]-(b),
	(b)<--(i:PatientID)-->(y),
	(b)<--(t:", opt$timepoint, ")-->(y),
	(k:", opt$location, ")-->(y)
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
", sep = "")

sampletable <- as.data.frame(cypher(graph, sampleidquery))

save(sampletable, file=opt$output)
