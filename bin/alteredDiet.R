##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "vegan", "reshape2")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)
library("ggraph")

# Some nettools dependencies required bioconductor installations
# Follow the on-screen instructions

##############################
# Run Analysis & Save Output #
##############################

# Start the connection to the graph
# If you are getting a lack of permission, disable local permission on Neo4J
graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "neo4j")

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

##### ALPHA DIVERSITY AND CENTRALITY #####

routcentral <- lapply(c(1:length(routdiv)), function(i) {
	listelement <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement)), function(j) {
		listgraph <- listelement[[ j ]]
		patient <- unique(V(listgraph)$patientid)
		tp <- unique(V(listgraph)$timepoint)
		diettype <- unique(V(listgraph)$diet)
		centraldf <- as.data.frame(alpha_centrality(listgraph, weights = E(listgraph)$weight))
		colnames(centraldf) <- "acentrality"
		diversitydf <- as.data.frame(igraph::diversity(graph = listgraph, weights = E(listgraph)$weight))
		centraldf$label <- rownames(centraldf)
		colnames(diversitydf) <- "entropy"
		diversitydf$label <- rownames(diversitydf)
		centraldf <- merge(centraldf, diversitydf, by = "label")
		centraldf$subject <- patient
		centraldf$time <- tp
		centraldf$patientdiet <- diettype
		return(centraldf)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
rcentraldf <- as.data.frame(do.call(rbind, routcentral))
# Focus on the phages for this
rcentraldf <- rcentraldf[- grep("Bacteria", rcentraldf$label),]

centrality_boxplot <- ggplot(rcentraldf[c(rcentraldf$time %in% "TP10" | rcentraldf$time %in% "TP8"),], aes(x = patientdiet, y = acentrality)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Alpha Centrality")

diversity_boxplot <- ggplot(rcentraldf[c(rcentraldf$time %in% "TP10" | rcentraldf$time %in% "TP8"),], aes(x = patientdiet, y = entropy)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Shannon Entropy")

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

dietbetadiv <- ggplot(routhamnosame, aes(x = diettype, y = hdistval)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Hamming Distance")

wilcox.test(routhamnosame$hdistval ~ routhamnosame$diettype)

# Plot NMDS
routmatrixsub <- as.dist(dcast(routham[,c("patient1tp", "patient2tp", "hdistval")], formula = patient1tp ~ patient2tp, value.var = "hdistval")[,-1])
ORD_NMDS <- metaMDS(routmatrixsub,k=2)
ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
ORD_FIT$SampleID <- rownames(ORD_FIT)
# Get metadata
routmetadata <- unique(routham[,c("patient1tp", "diettype")])
# Merge metadata
routmerge <- merge(ORD_FIT, routmetadata, by.x = "SampleID", by.y = "patient1tp")

plotnmds <- ggplot(routmerge, aes(x=MDS1, y=MDS2, colour=diettype)) +
    theme_classic() +
    geom_point() +
    scale_color_manual(values = wes_palette("Royal1"))

# Calculate statistical significance
mod <- betadisper(routmatrixsub, routmerge[,length(routmerge)])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
limits <- aes(ymax = upr, ymin=lwr)
plotdiffs <- ggplot(moddf, aes(y=diff, x=comparison)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")

boxplots <- plot_grid(centrality_boxplot, diversity_boxplot, intrabetadiv, dietbetadiv, labels = c("B", "C", "D", "E"), ncol = 2)
finalplot <- plot_grid(plotnmds, boxplots, ncol = 2, labels = c("A"))

pdf("./figures/dietnetworks.pdf", width = 10, height = 5)
	finalplot
dev.off()



as_adjacency_matrix(routdiv[[4]][[2]], attr="weight")

sqrt(sum((M1 - M2) ^ 2 ))



