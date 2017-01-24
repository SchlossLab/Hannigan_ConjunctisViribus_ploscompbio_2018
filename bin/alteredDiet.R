##################
# Load Libraries #
##################
gcinfo(FALSE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "vegan", "reshape2", "NetSwan")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)

# Some nettools dependencies required bioconductor installations
# Follow the on-screen instructions

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "root")

# Get list of the sample IDs
sampleidquery <- "
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

sampletable <- as.data.frame(cypher(graph, sampleidquery))

head(sampletable)

# get subsampling depth
phageminseq <- min(ddply(sampletable, c("PatientID", "TimePoint"), summarize, sum = sum(PhageAbundance))$sum)
bacminseq <- min(ddply(sampletable, c("PatientID", "TimePoint"), summarize, sum = sum(BacteriaAbundance))$sum)

# Rarefy each sample using sequence counts
rout <- lapply(unique(sampletable$PatientID), function(i) {
	subsetdfout <- as.data.frame(sampletable[c(sampletable$PatientID %in% i),])
	outputin <- lapply(unique(subsetdfout$TimePoint), function(j) {
		subsetdfin <- subsetdfout[c(subsetdfout$TimePoint %in% j),]
		subsetdfin$PhageAbundance <- c(rrarefy(subsetdfin$PhageAbundance, sample = phageminseq))
		subsetdfin$BacteriaAbundance <- c(rrarefy(subsetdfin$BacteriaAbundance, sample = bacminseq))
		return(subsetdfin)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})

# Finish making subsampled data frame
rdf <- as.data.frame(do.call(rbind, rout))
# Remove those without bacteria or phage nodes after subsampling
# Zero here means loss of the node
rdf <- rdf[!c(rdf$PhageAbundance == 0 | rdf$BacteriaAbundance == 0),]
# Calculate edge values from nodes
rdf$edge <- log10(rdf$PhageAbundance * rdf$BacteriaAbundance)

# Make a list of subgraphs for each of the samples
# This will be used for diversity, centrality, etc
routdiv <- lapply(unique(rdf$PatientID), function(i) {
	subsetdfout <- as.data.frame(rdf[c(rdf$PatientID %in% i),])
	outputin <- lapply(unique(subsetdfout$TimePoint), function(j) {
		subsetdfin <- subsetdfout[c(subsetdfout$TimePoint %in% j),]
		lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = FALSE)
		E(lapgraph)$weight <- subsetdfin[,c("edge")]
		V(lapgraph)$timepoint <- j
		V(lapgraph)$patientid <- i
		diettype <- unique(subsetdfin$Diet)
		V(lapgraph)$diet <- diettype
		return(lapgraph)
	})
	return(outputin)
})

# Also make a list of subgraphs for hi and
# low fat diets, including all samples.
routdisease <- lapply(unique(rdf$Diet), function(i) {
	subsetdfout <- as.data.frame(rdf[c(rdf$Diet %in% i),])
	lapgraph <- graph_from_data_frame(subsetdfout[,c("to", "from")], directed = FALSE)
	E(lapgraph)$weight <- subsetdfout[,c("edge")]
	diettype <- unique(subsetdfout$Diet)
	V(lapgraph)$diet <- diettype
	V(lapgraph)$patientid <- i
	return(lapgraph)
})

##### ALPHA DIVERSITY AND CENTRALITY #####

### Alpha centrality & Shannon entropy per sample

routcentral <- lapply(c(1:length(routdiv)), function(i) {
	listelement <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement)), function(j) {
		listgraph <- listelement[[ j ]]
		ec <- centr_eigen(listgraph)$centralization

		bt <- centr_betw(listgraph)$centralization

		cl <- centr_clo(listgraph)$centralization

		dg <- centr_degree(listgraph)$centralization

		di <- diameter(listgraph)

		patient <- unique(V(listgraph)$patientid)
		tp <- unique(V(listgraph)$timepoint)
		diettype <- unique(V(listgraph)$diet)

		centraldf <- c(patient, tp, diettype, ec, bt, cl, dg, di)
		return(centraldf)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
rcentraldf <- as.data.frame(do.call(rbind, routcentral))
colnames(rcentraldf) <- c("patient", "time", "patientdiet", "ec", "bt", "cl", "dg", "di")
rcentraldf$ec <- as.numeric(rcentraldf$ec)
rcentraldf$bt <- as.numeric(rcentraldf$bt)
rcentraldf$cl <- as.numeric(rcentraldf$cl)
rcentraldf$dg <- as.numeric(rcentraldf$dg)
rcentraldf$di <- as.numeric(rcentraldf$di)
# Focus on the phages for this
binlength <- c(1:2) + 0.5
didgbox <- ggplot(rcentraldf[c(rcentraldf$time %in% "TP10" | rcentraldf$time %in% "TP8"),], aes(x = patientdiet, y = dg)) +
	theme_classic() +
	geom_dotplot(fill=wes_palette("Royal1")[2], binaxis = "y", binwidth = 0.0025, stackdir = "center") +
	ylab("Degree Centrality") +
	xlab("") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	) +
	stat_summary(fun.y = mean, fun.ymin = mean, fun.ymax = mean, geom = "crossbar", width = 0.5) +
	geom_vline(xintercept=binlength,color="grey")

diclbox <- ggplot(rcentraldf[c(rcentraldf$time %in% "TP10" | rcentraldf$time %in% "TP8"),], aes(x = patientdiet, y = cl)) +
	theme_classic() +
	geom_dotplot(fill=wes_palette("Royal1")[2], binaxis = "y", binwidth = 0.0025, stackdir = "center") +
	ylab("Closeness Centrality") +
	xlab("") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	) +
	stat_summary(fun.y = mean, fun.ymin = mean, fun.ymax = mean, geom = "crossbar", width = 0.5) +
	geom_vline(xintercept=binlength,color="grey")

t.test(rcentraldf[c(rcentraldf$time %in% "TP10" | rcentraldf$time %in% "TP8"),]$dg ~ rcentraldf[c(rcentraldf$time %in% "TP10" | rcentraldf$time %in% "TP8"),]$patientdiet)

##### Obesity #####
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "root")

# Get list of the sample IDs
sampleidquery <- "
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

sampletable <- as.data.frame(cypher(graph, sampleidquery))

head(sampletable)

# get subsampling depth
phageminseq <- min(ddply(sampletable, c("PatientID", "TimePoint"), summarize, sum = sum(PhageAbundance))$sum)
bacminseq <- min(ddply(sampletable, c("PatientID", "TimePoint"), summarize, sum = sum(BacteriaAbundance))$sum)

# Rarefy each sample using sequence counts
rout <- lapply(unique(sampletable$PatientID), function(i) {
	subsetdfout <- as.data.frame(sampletable[c(sampletable$PatientID %in% i),])
	outputin <- lapply(unique(subsetdfout$TimePoint), function(j) {
		subsetdfin <- subsetdfout[c(subsetdfout$TimePoint %in% j),]
		subsetdfin$PhageAbundance <- c(rrarefy(subsetdfin$PhageAbundance, sample = phageminseq))
		subsetdfin$BacteriaAbundance <- c(rrarefy(subsetdfin$BacteriaAbundance, sample = bacminseq))
		return(subsetdfin)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})

# Finish making subsampled data frame
rdf <- as.data.frame(do.call(rbind, rout))
# Remove those without bacteria or phage nodes after subsampling
# Zero here means loss of the node
rdf <- rdf[!c(rdf$PhageAbundance == 0 | rdf$BacteriaAbundance == 0),]
# Calculate edge values from nodes
rdf$edge <- log10(rdf$PhageAbundance * rdf$BacteriaAbundance)

# Make a list of subgraphs for each of the samples
# This will be used for diversity, centrality, etc
routdiv <- lapply(unique(rdf$PatientID), function(i) {
	subsetdfout <- as.data.frame(rdf[c(rdf$PatientID %in% i),])
	outputin <- lapply(unique(subsetdfout$TimePoint), function(j) {
		subsetdfin <- subsetdfout[c(subsetdfout$TimePoint %in% j),]
		lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = FALSE)
		E(lapgraph)$weight <- subsetdfin[,c("edge")]
		V(lapgraph)$timepoint <- j
		V(lapgraph)$patientid <- i
		diettype <- unique(subsetdfin$Diet)
		V(lapgraph)$diet <- diettype
		return(lapgraph)
	})
	return(outputin)
})

routcentral <- lapply(c(1:length(routdiv)), function(i) {
	listelement <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement)), function(j) {
		listgraph <- listelement[[ j ]]
		ec <- centr_eigen(listgraph)$centralization

		bt <- centr_betw(listgraph)$centralization

		cl <- centr_clo(listgraph)$centralization

		dg <- centr_degree(listgraph)$centralization

		di <- diameter(listgraph)

		patient <- unique(V(listgraph)$patientid)
		tp <- unique(V(listgraph)$timepoint)
		diettype <- unique(V(listgraph)$diet)

		centraldf <- c(patient, tp, diettype, ec, bt, cl, dg, di)
		return(centraldf)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
rcentraldf <- as.data.frame(do.call(rbind, routcentral))
colnames(rcentraldf) <- c("patient", "time", "patientdiet", "ec", "bt", "cl", "dg", "di")
rcentraldf$ec <- as.numeric(rcentraldf$ec)
rcentraldf$bt <- as.numeric(rcentraldf$bt)
rcentraldf$cl <- as.numeric(rcentraldf$cl)
rcentraldf$dg <- as.numeric(rcentraldf$dg)
rcentraldf$di <- as.numeric(rcentraldf$di)

# Add information for family and twins
rcentraldf$family <- gsub("[MT].*", "", rcentraldf$patient, perl = TRUE)
# Get whether they are a twin or mother
rcentraldf$person <- gsub("F\\d", "", rcentraldf$patient, perl = TRUE)

rcentraldfmothers <- rcentraldf[c(rcentraldf$person %in% "M"),]

binlength <- c(1:2) + 0.5
obdgbox <- ggplot(rcentraldfmothers, aes(x = patientdiet, y = dg)) +
	theme_classic() +
	geom_dotplot(fill=wes_palette("Royal1")[2], binaxis = "y", binwidth = 0.005, stackdir = "center") +
	ylab("Degree Centrality") +
	xlab("") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	)

obclbox <- ggplot(rcentraldfmothers, aes(x = patientdiet, y = cl)) +
	theme_classic() +
	geom_dotplot(fill=wes_palette("Royal1")[2], binaxis = "y", binwidth = 0.005, stackdir = "center") +
	ylab("Closeness Centrality") +
	xlab("") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	)

boxplots <- plot_grid(didgbox, diclbox, obdgbox, obclbox, labels = c("A", "B", "C", "D"), nrow = 1)

pdf("./figures/dietnetworks.pdf", width = 10, height = 4)
	boxplots
dev.off()

