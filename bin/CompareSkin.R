##################
# Load Libraries #
##################
gcinfo(TRUE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "scales", "plyr", "cowplot", "vegan", "reshape2", "parallel", "stringr", "NetSwan")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)

# Some nettools dependencies required bioconductor installations
# Follow the on-screen instructions

##############################
# Run Analysis & Save Output #
##############################
# Import graphs into a list
skinsites <- c("Ax", "Ac", "Pa", "Tw", "Um", "Fh", "Ra")
# Start list
graphdf <- data.frame()

for (i in skinsites) {
	print(i)
	filename <- paste("./data/skingraph-", i, ".Rdata", sep = "")
	load(file = filename)
	graphdf <- rbind(graphdf, sampletable)
	rm(sampletable)
}

rm(i)

graphdf <- graphdf[-4]

# See the object size
format(object.size(graphdf), units = "MB")

# Run subsampling
uniquephagegraph <- unique(graphdf[-c(2,6)])
phageminseq <- min(ddply(uniquephagegraph, c("PatientID", "Location"), summarize, sum = sum(as.numeric(PhageAbundance)))$sum)
print(format(object.size(uniquephagegraph), units = "MB"))

uniquebacteriagraph <- unique(graphdf[-c(1,5)])
bacminseq <- min(ddply(uniquebacteriagraph, c("PatientID", "Location"), summarize, sum = sum(as.numeric(BacteriaAbundance)))$sum)
print(format(object.size(uniquephagegraph), units = "MB"))

# Rarefy each sample using sequence counts
rout <- lapply(unique(uniquephagegraph$PatientID), function(i) {
	outputin <- lapply(unique(as.data.frame(uniquephagegraph[c(uniquephagegraph$PatientID %in% i),])$Location), function(j) {
		print(c(i, j))
		subsetdfin <- as.data.frame(uniquephagegraph[c(uniquephagegraph$PatientID %in% i),])[c(as.data.frame(uniquephagegraph[c(uniquephagegraph$PatientID %in% i),])$Location %in% j),]
		subsetdfin$PhageAbundance <- c(rrarefy(subsetdfin$PhageAbundance, sample = phageminseq))
		return(subsetdfin)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	rm(outputin)
	return(forresult)
})
rdfphage <- as.data.frame(do.call(rbind, rout))
rdfphage$combophage <- paste(rdfphage$from, rdfphage$PatientID, rdfphage$Location, sep = "__")
rdfphage <- rdfphage[-c(1:3)]

rout <- lapply(unique(uniquebacteriagraph$PatientID), function(i) {
	outputin <- lapply(unique(as.data.frame(uniquebacteriagraph[c(uniquebacteriagraph$PatientID %in% i),])$Location), function(j) {
		print(c(i, j))
		subsetdfin <- as.data.frame(uniquebacteriagraph[c(uniquebacteriagraph$PatientID %in% i),])[c(as.data.frame(uniquebacteriagraph[c(uniquebacteriagraph$PatientID %in% i),])$Location %in% j),]
		subsetdfin$BacteriaAbundance <- c(rrarefy(subsetdfin$BacteriaAbundance, sample = bacminseq))
		return(subsetdfin)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	rm(outputin)
	return(forresult)
})
rdfbacteria <- as.data.frame(do.call(rbind, rout))
rdfbacteria$combobacteria <- paste(rdfbacteria$to, rdfbacteria$PatientID, rdfbacteria$Location, sep = "__")
rdfbacteria <- rdfbacteria[-c(1:3)]

# Merge the subsampled abundances back into the original file
graphdfcombo <- graphdf
graphdfcombo$combophage <- paste(graphdfcombo$from, graphdfcombo$PatientID, graphdfcombo$Location, sep = "__")
graphdfcombo$combobacteria <- paste(graphdfcombo$to, graphdfcombo$PatientID, graphdfcombo$Location, sep = "__")
graphdfcombo <- graphdfcombo[-c(1:6)]

format(object.size(graphdfcombo), units = "MB")
format(object.size(rdfphage), units = "KB")

graphdfmerge <- merge(graphdfcombo, rdfphage, by = "combophage")
graphdfmerge <- merge(graphdfmerge, rdfbacteria, by = "combobacteria")

# Remove those without bacteria or phage nodes after subsampling
# Zero here means loss of the node
rdf <- graphdfmerge[!c(graphdfmerge$PhageAbundance == 0 | graphdfmerge$BacteriaAbundance == 0),]
# Calculate edge values from nodes
rdf$edge <- log10(rdf$PhageAbundance * rdf$BacteriaAbundance) + 0.0001
# Parse the values again
rdf <- cbind(as.data.frame(str_split_fixed(rdf$combobacteria, "__", 3)), rdf)
rdf <- cbind(as.data.frame(str_split_fixed(rdf$combophage, "__", 3)), rdf)
rdf <- rdf[-c(2:3)]
rdf <- rdf[-c(5:6)]
colnames(rdf) <- c("from", "to", "PatientID", "Location", "PhageAbundance", "BacteriaAbundance", "edge")

# Make a list of subgraphs for each of the samples
# This will be used for diversity, centrality, etc
routdiv <- lapply(unique(rdf$PatientID), function(i) {
	subsetdfout <- as.data.frame(rdf[c(rdf$PatientID %in% i),])
	outputin <- lapply(unique(subsetdfout$Location), function(j) {
		subsetdfin <- subsetdfout[c(subsetdfout$Location %in% j),]
		lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = TRUE)
		E(lapgraph)$weight <- subsetdfin[,c("edge")]
		print(as.character(j))
		V(lapgraph)$location <- as.character(j)
		V(lapgraph)$patientid <- i
		return(lapgraph)
	})
	return(outputin)
})

routcentral <- lapply(c(1:length(routdiv)), function(i) {
	listelement <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement)), function(j) {
		listgraph <- listelement[[ j ]]
		patient <- unique(V(listgraph)$patientid)
		location <- unique(V(listgraph)$location)
		print(c(patient, location))
		centraldf <- as.data.frame(alpha_centrality(listgraph, weights = E(listgraph)$weight))
		colnames(centraldf) <- "acentrality"
		
		pagerank <- as.data.frame(page_rank(listgraph, weights = E(listgraph)$weight, directed = FALSE)$vector)
		colnames(pagerank) <- "page_rank"
		pagerank$label <- rownames(pagerank)

		# swaneff <- as.data.frame(swan_efficiency(listgraph))
		# colnames(swaneff) <- "swan_efficiency"
		# pagerank <- cbind(pagerank, swaneff)

		diversitydf <- as.data.frame(igraph::diversity(graph = listgraph, weights = E(listgraph)$weight))
		centraldf$label <- rownames(centraldf)
		colnames(diversitydf) <- "entropy"
		diversitydf$label <- rownames(diversitydf)
		centraldf <- merge(centraldf, diversitydf, by = "label")
		centraldf <- merge(centraldf, pagerank, by = "label")
		centraldf$subject <- patient
		centraldf$Location <- location
		return(centraldf)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
rcentraldf <- as.data.frame(do.call(rbind, routcentral))
# Focus on the phages for this
rcentraldf <- rcentraldf[- grep("Bacteria", rcentraldf$label),]

alpha_centrality_boxplot_all <- ggplot(rcentraldf, aes(x = factor(Location), y = acentrality)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Alpha Centrality")

pairwise.wilcox.test(x = rcentraldf$acentrality, g = rcentraldf$Location)

pagerank_boxplot_all <- ggplot(rcentraldf, aes(x = factor(Location), y = page_rank)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Page Rank")

pairwise.wilcox.test(x = rcentraldf$page_rank, g = rcentraldf$Location)

diversity_boxplot_all <- ggplot(rcentraldf, aes(x = factor(Location), y = entropy)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Shannon Entropy")

pairwise.wilcox.test(x = rcentraldf$entropy, g = rcentraldf$Location)

##### Diameter #####
# This is a weighted diamter
diameterreading <- lapply(c(1:length(routdiv)), function(i) {
	listelement <- routdiv[[ i ]]
	outputin <- lapply(c(1:length(listelement)), function(j) {
		listgraph <- listelement[[ j ]]
		patient <- unique(V(listgraph)$patientid)
		Location <- unique(V(listgraph)$location)
		centraldf <- as.data.frame(diameter(listgraph, weights = E(listgraph)$weight))
		colnames(centraldf) <- "samplediamter"
		centraldf$subject <- patient
		centraldf$Location <- Location
		return(centraldf)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})
diadf <- as.data.frame(do.call(rbind, diameterreading))

diameter_boxplot <- ggplot(diadf, aes(x = Location, y = samplediamter)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Weighted Diamter")

pairwise.wilcox.test(x = diadf$samplediamter, g = diadf$Location)

### Differences by broader location classification ###

# Make a data frame with the occlusion and moisture status sort
# that I can merge it in with my existing data.
moisture <- c("Moist", "IntMoist", "IntMoist", "Moist", "Moist", "Sebaceous", "Sebaceous")
occlusion <- c("Occluded", "IntOccluded", "Exposed", "Occluded", "Occluded", "Exposed", "Occluded")
locationmetadata <- data.frame(skinsites, moisture, occlusion)

rcentralmerge <- merge(rcentraldf, locationmetadata, by.x = "Location", by.y = "skinsites")
diamerge <- merge(diadf, locationmetadata, by.x = "Location", by.y = "skinsites")

# Moisture Levels

alpha_centrality_boxplot_moist <- ggplot(rcentralmerge, aes(x = factor(moisture), y = acentrality)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Alpha Centrality")

pairwise.wilcox.test(x = rcentralmerge$acentrality, g = rcentralmerge$moisture)

pagerank_boxplot_moist <- ggplot(rcentralmerge, aes(x = factor(moisture), y = page_rank)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Page Rank")

pairwise.wilcox.test(x = rcentralmerge$page_rank, g = rcentralmerge$moisture)

diversity_boxplot_moist <- ggplot(rcentralmerge, aes(x = factor(moisture), y = entropy)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Shannon Entropy")

pairwise.wilcox.test(x = rcentralmerge$entropy, g = rcentralmerge$moisture)

diameter_boxplot_moist <- ggplot(diamerge, aes(x = moisture, y = samplediamter)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Weighted Diamter")

pairwise.wilcox.test(x = diamerge$samplediamter, g = diamerge$moisture)

# Occlusion Status

alpha_centrality_boxplot_occ <- ggplot(rcentralmerge, aes(x = factor(occlusion), y = acentrality)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Alpha Centrality")

pairwise.wilcox.test(x = rcentralmerge$acentrality, g = rcentralmerge$occlusion)

pagerank_boxplot_occ <- ggplot(rcentralmerge, aes(x = factor(occlusion), y = page_rank)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Page Rank") +
	scale_y_log10()

pairwise.wilcox.test(x = rcentralmerge$page_rank, g = rcentralmerge$occlusion)

diversity_boxplot_occ <- ggplot(rcentralmerge, aes(x = factor(occlusion), y = entropy)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Shannon Entropy") +
	scale_y_log10()

pairwise.wilcox.test(x = rcentralmerge$entropy, g = rcentralmerge$occlusion)

diameter_boxplot_occ <- ggplot(diamerge, aes(x = occlusion, y = samplediamter)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Weighted Diamter")

pairwise.wilcox.test(x = diamerge$samplediamter, g = diamerge$occlusion)

# Beta diversity between graphs
# Proportion of shared edges between graphs

hamming_distance <- function(g1, g2) {
	intersection <- length(E(intersection(g1, g2)))
	length1 <- length(E(g1))
	length2 <- length(E(g2))
	return(1 - intersection / (length1 + length2 - intersection))
}

# routham <- lapply(c(1:length(routdiv)), function(i) {
# 	listelement1 <- routdiv[[ i ]]
# 	outputin <- lapply(c(1:length(listelement1)), function(j) {
# 		listgraph1 <- listelement1[[ j ]]
# 		outdf1 <- lapply(c(1:length(routdiv)), function(k) {
# 			listelement2 <- routdiv[[ k ]]
# 				outdf2 <- lapply(c(1:length(listelement2)), function(l) {
# 					print(c(i,j,k,l))
# 					listgraph2 <- listelement2[[ l ]]
# 					patient1 <- unique(V(listgraph1)$patientid)
# 					patient2 <- unique(V(listgraph2)$patientid)
# 					patient1tp <- paste(unique(V(listgraph1)$patientid), unique(V(listgraph1)$location), sep = "")
# 					patient2tp <- paste(unique(V(listgraph2)$patientid), unique(V(listgraph2)$location), sep = "")
# 					hdistval <- hamming_distance(listgraph1, listgraph2)
# 					outdftop <- data.frame(patient1, patient2, patient1tp, patient2tp, hdistval)
# 					return(outdftop)
# 				})
# 			inresulttop <- as.data.frame(do.call(rbind, outdf2))
# 			return(inresulttop)
# 		})
# 		inresultmiddle <- as.data.frame(do.call(rbind, outdf1))
# 		return(inresultmiddle)
# 	})
# 	forresult <- as.data.frame(do.call(rbind, outputin))
# 	return(forresult)
# })

# save(routham, file = "./skinbetadivbackup.Rdata")

load(file = "./skinbetadivbackup.Rdata")

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

routhamnosame$locationclass <- ifelse(routhamnosame$location1 == routhamnosame$location2, "Intrasite", "Intersite")

# Showing that people are more similar to themselves than other people
# across skin sites

# I could also try running this over time in addition to at a single
# time point.

intrabetadiv_location <- ggplot(routhamnosame, aes(x = locationclass, y = hdistval)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Hamming Distance")

wilcox.test(routhamnosame$hdistval ~ routhamnosame$locationclass)

# Ordination differences

routmatrixsub <- as.dist(dcast(routhamnosame[,c("patient1tp", "patient2tp", "hdistval")], formula = patient1tp ~ patient2tp, value.var = "hdistval")[,-1])
ORD_NMDS <- metaMDS(routmatrixsub, k = 2)
ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
ORD_FIT$SampleID <- rownames(ORD_FIT)

routmetadata <- unique(routhamnosame[,c("patient1tp", "location1")])
routmetadata$tmprows <- as.numeric(rownames(routmetadata))

routmerge <- merge(ORD_FIT, routmetadata, by.x = "SampleID", by.y = "patient1tp")

routmerge <- merge(routmerge, locationmetadata, by.x = "location1", by.y = "skinsites")

routmerge <- routmerge[order(routmerge$tmprows),-5]

plotnmds_location <- ggplot(routmerge, aes(x=MDS1, y=MDS2, colour=location1)) +
    theme_classic() +
    geom_point()

plotnmds_moist <- ggplot(routmerge, aes(x=MDS1, y=MDS2, colour=moisture)) +
    theme_classic() +
    geom_point() +
    scale_color_manual(values = wes_palette("Royal1")[c(1,2,4)])

plotnmds <- ggplot(routmerge[!c(routmerge$moisture %in% "IntMoist"),], aes(x=MDS1, y=MDS2, colour=moisture)) +
    theme_classic() +
    geom_point() +
    scale_color_manual(values = wes_palette("Royal1")[c(1,2,4)])

plotnmds_occ <- ggplot(routmerge, aes(x=MDS1, y=MDS2, colour=occlusion)) +
    theme_classic() +
    geom_point() +
    scale_color_manual(values = wes_palette("Royal1")[c(1,2,4)])

anosim(routmatrixsub, routmerge$location1)
anosim(routmatrixsub, routmerge$moisture)
anosim(routmatrixsub, routmerge$occlusion)

# Calculate statistical significance
mod <- betadisper(routmatrixsub, routmerge[,length(routmerge)])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
limits <- aes(ymax = upr, ymin=lwr)
plotdiffs_occ <- ggplot(moddf, aes(y=diff, x=comparison)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")

# Calculate statistical significance
mod <- betadisper(routmatrixsub, routmerge[,"moisture"])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
limits <- aes(ymax = upr, ymin=lwr)
plotdiffs_moist <- ggplot(moddf, aes(y=diff, x=comparison)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")



mod <- betadisper(routmatrixsub, routmerge[,1])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
limits <- aes(ymax = upr, ymin=lwr)
plotdiffs_all <- ggplot(moddf, aes(y=diff, x=comparison)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")

# Plot the results
location <- plot_grid(
	diameter_boxplot,
	alpha_centrality_boxplot_all,
	pagerank_boxplot_all,
	diversity_boxplot_all,
	plotdiffs_all,
	plotnmds_location,
	labels = c("A", "B", "C", "D", "E", "F"), nrow = 1)

moisture <- plot_grid(
	diameter_boxplot_moist,
	alpha_centrality_boxplot_moist,
	pagerank_boxplot_moist,
	diversity_boxplot_moist,
	plotdiffs_moist,
	plotnmds_moist,
	labels = c("G", "H", "I", "J", "K", "L"), nrow = 1)

occluded <- plot_grid(
	diameter_boxplot_occ,
	alpha_centrality_boxplot_occ,
	pagerank_boxplot_occ,
	diversity_boxplot_occ,
	plotdiffs_occ,
	plotnmds_occ,
	labels = c("M", "N", "O", "P", "Q", "R"), nrow = 1)

threeplots <- plot_grid(location, moisture, occluded, ncol = 1)

interpersonalplot <- plot_grid(intrabetadiv_personal, intrabetadiv_location, nrow = 1, labels = c("A", "B"))

pdf("./figures/skinplotresults.pdf", width = 20, height = 8)
	threeplots
dev.off()

pdf("./figures/skininterpersonal.pdf", width = 8, height = 4)
	interpersonalplot
dev.off()
