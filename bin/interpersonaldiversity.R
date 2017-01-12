##################
# Load Libraries #
##################
gcinfo(TRUE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "vegan", "reshape2", "NetSwan")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)

##############
# Diet Graph #
##############
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
		lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = TRUE)
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
	lapgraph <- graph_from_data_frame(subsetdfout[,c("to", "from")], directed = TRUE)
	E(lapgraph)$weight <- subsetdfout[,c("edge")]
	diettype <- unique(subsetdfout$Diet)
	V(lapgraph)$diet <- diettype
	V(lapgraph)$patientid <- i
	return(lapgraph)
})

##### Beta Diversity #####
hamming_distance <- function(g1, g2) {
	intersection <- length(E(intersection(g1, g2)))
	length1 <- length(E(g1))
	length2 <- length(E(g2))
	return(1 - intersection / (length1 + length2 - intersection))
}

routham <- lapply(c(1:length(routdiv)), function(i) {
	listelement1 <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement1)), function(j) {
		listgraph1 <- listelement1[[ j ]]
		outdf1 <- lapply(c(1:length(routdiv)), function(k) {
			listelement2 <- routdiv[[ k ]]
				outdf2 <- lapply(c(1:length(listelement2)), function(l) {
					listgraph2 <- listelement2[[ l ]]
					patient1 <- unique(V(listgraph1)$patientid)
					patient2 <- unique(V(listgraph2)$patientid)
					patient1tp <- paste(unique(V(listgraph1)$patientid), unique(V(listgraph1)$timepoint), sep = "")
					patient2tp <- paste(unique(V(listgraph2)$patientid), unique(V(listgraph2)$timepoint), sep = "")
					diettype <- unique(V(listgraph1)$diet)
					hdistval <- hamming_distance(listgraph1, listgraph2)
					outdftop <- data.frame(patient1, patient2, diettype, patient1tp, patient2tp, hdistval)
					return(outdftop)
				})
			inresulttop <- as.data.frame(do.call(rbind, outdf2))
			return(inresulttop)
		})
		inresultmiddle <- as.data.frame(do.call(rbind, outdf1))
		return(inresultmiddle)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
routham <- as.data.frame(do.call(rbind, routham))
routhamnosame <- routham[!c(routham$hdistval == 0),]

routhamnosame$class <- ifelse(routhamnosame$patient1 == routhamnosame$patient2, "Intrapersonal", "Interpersonal")

intrabetadiv <- ggplot(routhamnosame, aes(x = class, y = hdistval)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Hamming Distance")

wilcox.test(routhamnosame$hdistval ~ routhamnosame$class)

routmatrixsub <- as.dist(dcast(routham[,c("patient1tp", "patient2tp", "hdistval")], formula = patient1tp ~ patient2tp, value.var = "hdistval")[,-1])
ORD_NMDS <- metaMDS(routmatrixsub,k=2)
ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
ORD_FIT$SampleID <- rownames(ORD_FIT)
# Get metadata
routmetadata <- unique(routham[,c("patient1tp", "diettype")])
# Merge metadata
routmerge <- merge(ORD_FIT, routmetadata, by.x = "SampleID", by.y = "patient1tp")

routmerge$subject <- gsub("TP\\d+", "", routmerge$SampleID)
routmerge$timepoint <- gsub("^\\d+", "", routmerge$SampleID)

plotnmds_dietstudy <- ggplot(routmerge, aes(x=MDS1, y=MDS2, colour=subject)) +
    theme_classic() +
    geom_point()

anosim(routmatrixsub, routmerge$subject)

##############
# Skin Graph #
##############
load(file = "./skinbetadivbackup.Rdata")

skinsites <- c("Ax", "Ac", "Pa", "Tw", "Um", "Fh", "Ra")
moisture <- c("Moist", "IntMoist", "IntMoist", "Moist", "Moist", "Sebaceous", "Sebaceous")
occlusion <- c("Occluded", "IntOccluded", "Exposed", "Occluded", "Occluded", "Exposed", "Occluded")
locationmetadata <- data.frame(skinsites, moisture, occlusion)

routham <- as.data.frame(do.call(rbind, routham))
routhamnosame <- routham[!c(routham$hdistval == 0),]
routhamnosame$location1 <- gsub("\\d+", "", routhamnosame$patient1tp, perl = TRUE)
routhamnosame$location2 <- gsub("\\d+", "", routhamnosame$patient2tp, perl = TRUE)


# Interpersonal Differences

routhamnosame$class <- ifelse(routhamnosame$patient1 == routhamnosame$patient2, "Intrapersonal", "Interpersonal")

# Showing that people are more similar to themselves than other people
# across skin sites

# I could also try running this over time in addition to at a single
# time point.

intrabetadiv_personal <- ggplot(routhamnosame, aes(x = class, y = hdistval)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Hamming Distance")

wilcox.test(routhamnosame$hdistval ~ routhamnosame$class)

routmatrixsub <- as.dist(dcast(routhamnosame[,c("patient1tp", "patient2tp", "hdistval")], formula = patient1tp ~ patient2tp, value.var = "hdistval")[,-1])
ORD_NMDS <- metaMDS(routmatrixsub, k = 2)
ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
ORD_FIT$SampleID <- rownames(ORD_FIT)

routmetadata <- unique(routhamnosame[,c("patient1tp", "location1")])
routmetadata$tmprows <- as.numeric(rownames(routmetadata))

routmerge <- merge(ORD_FIT, routmetadata, by.x = "SampleID", by.y = "patient1tp")

routmerge <- merge(routmerge, locationmetadata, by.x = "location1", by.y = "skinsites")

routmerge <- routmerge[order(routmerge$tmprows),-5]

routmerge$subject <- gsub("[^\\d]+$", "", routmerge$SampleID, perl = TRUE)

plotnmds_subject <- ggplot(routmerge, aes(x=MDS1, y=MDS2, colour=subject)) +
    theme_classic() +
    geom_point()

##############
# Twin Graph #
##############
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
		lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = TRUE)
		E(lapgraph)$weight <- subsetdfin[,c("edge")]
		V(lapgraph)$timepoint <- j
		V(lapgraph)$patientid <- i
		diettype <- unique(subsetdfin$Diet)
		V(lapgraph)$diet <- diettype
		return(lapgraph)
	})
	return(outputin)
})

hamming_distance <- function(g1, g2) {
	intersection <- length(E(intersection(g1, g2)))
	length1 <- length(E(g1))
	length2 <- length(E(g2))
	return(1 - intersection / (length1 + length2 - intersection))
}

routham <- lapply(c(1:length(routdiv)), function(i) {
	listelement1 <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement1)), function(j) {
		listgraph1 <- listelement1[[ j ]]
		outdf1 <- lapply(c(1:length(routdiv)), function(k) {
			listelement2 <- routdiv[[ k ]]
				outdf2 <- lapply(c(1:length(listelement2)), function(l) {
					print(c(i,j,k,l))
					listgraph2 <- listelement2[[ l ]]
					patient1 <- unique(V(listgraph1)$patientid)
					patient2 <- unique(V(listgraph2)$patientid)
					patient1tp <- paste(unique(V(listgraph1)$patientid), unique(V(listgraph1)$timepoint), sep = "")
					patient2tp <- paste(unique(V(listgraph2)$patientid), unique(V(listgraph2)$timepoint), sep = "")
					diettype <- unique(V(listgraph1)$diet)
					hdistval <- hamming_distance(listgraph1, listgraph2)
					outdftop <- data.frame(patient1, patient2, diettype, patient1tp, patient2tp, hdistval)
					return(outdftop)
				})
			inresulttop <- as.data.frame(do.call(rbind, outdf2))
			return(inresulttop)
		})
		inresultmiddle <- as.data.frame(do.call(rbind, outdf1))
		return(inresultmiddle)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
routham <- as.data.frame(do.call(rbind, routham))
routhamnosame <- routham[!c(routham$hdistval == 0),]

routhamnosame$family1 <- gsub("[TM].*", "", routhamnosame$patient1, perl = TRUE)
routhamnosame$family2 <- gsub("[TM].*", "", routhamnosame$patient2, perl = TRUE)
routhamnosame$person1 <- gsub("F\\d", "", routhamnosame$patient1, perl = TRUE)
routhamnosame$person1 <- gsub("\\d", "", routhamnosame$person1, perl = TRUE)
routhamnosame$person2 <- gsub("F\\d", "", routhamnosame$patient2, perl = TRUE)
routhamnosame$person2 <- gsub("\\d", "", routhamnosame$person2, perl = TRUE)

routhamnosame$class <- ifelse(routhamnosame$family1 == routhamnosame$family2, "Intrafamily", "Interfamily")

intrabetadivwithmothers <- ggplot(routhamnosame, aes(x = class, y = hdistval)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Hamming Distance")

wilcox.test(routhamnosame$hdistval ~ routhamnosame$class)

routhamnosame <- routhamnosame[c(routhamnosame$person1 %in% "T" & routhamnosame$person2 %in% "T"),]

routhamnosame$class <- ifelse(routhamnosame$family1 == routhamnosame$family2, "Intrafamily", "Interfamily")

intrabetadiv_justtwins <- ggplot(routhamnosame, aes(x = class, y = hdistval)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Hamming Distance")

wilcox.test(routhamnosame$hdistval ~ routhamnosame$class)

boxplots <- plot_grid(
	intrabetadiv,
	intrabetadiv_personal,
	intrabetadivwithmothers,
	intrabetadiv_justtwins,
	labels = c("B", "C", "D", "E"), ncol = 2)

finalplot <- plot_grid(plotnmds_dietstudy, boxplots, labels = c("A"), rel_widths = c(1, 1))

pdf("./figures/intrapersonal_diversity.pdf", width = 10, height = 5)
	finalplot
dev.off()
