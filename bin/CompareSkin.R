##################
# Load Libraries #
##################
gcinfo(TRUE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "scales", "plyr", "cowplot", "vegan", "reshape2", "parallel", "stringr")
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
graphdfTP2 <- data.frame()
graphdfTP3 <- data.frame()

for (i in skinsites) {
	print(i)
	filename <- paste("./data/skingraph-", i, ".Rdata", sep = "")
	load(file = filename)
	graphdfTP2 <- rbind(graphdfTP2, sampletable)
	rm(sampletable)
}

rm(i)

for (i in skinsites) {
	print(i)
	filename <- paste("./data/skingraph-", i, "-TP3.Rdata", sep = "")
	load(file = filename)
	graphdfTP3 <- rbind(graphdfTP3, sampletable)
	rm(sampletable)
}

rm(i)

totalgraph <- rbind(graphdfTP2, graphdfTP3)

# See the object size
format(object.size(totalgraph), units = "MB")

# Run subsampling
uniquephagegraph <- unique(totalgraph[-c(2,7)])
phageminseq <- quantile(ddply(uniquephagegraph, c("PatientID", "Location", "TimePoint"), summarize, sum = sum(as.numeric(PhageAbundance)))$sum, 0.05)
print(format(object.size(uniquephagegraph), units = "MB"))

uniquebacteriagraph <- unique(totalgraph[-c(1,6)])
bacminseq <- quantile(ddply(uniquebacteriagraph, c("PatientID", "Location", "TimePoint"), summarize, sum = sum(as.numeric(BacteriaAbundance)))$sum, 0.05)
print(format(object.size(uniquephagegraph), units = "MB"))

# Rarefy each sample using sequence counts
rout <- lapply(unique(uniquephagegraph$PatientID), function(i) {

	outputout <- lapply(unique(uniquephagegraph$TimePoint), function(t) {

		outputin <- lapply(unique(as.data.frame(uniquephagegraph[c(uniquephagegraph$PatientID %in% i & uniquephagegraph$TimePoint %in% t),])$Location), function(j) {
			print(c(i, t, j))
			subsetdfin <- as.data.frame(uniquephagegraph[c(uniquephagegraph$PatientID %in% i & uniquephagegraph$TimePoint %in% t & uniquephagegraph$Location %in% j),])
			if (sum(subsetdfin$PhageAbundance) >= phageminseq) {
				subsetdfin$PhageAbundance <- c(rrarefy(subsetdfin$PhageAbundance, sample = phageminseq))
				return(subsetdfin)
			} else {
				NULL
			}
		})
		forresult <- as.data.frame(do.call(rbind, outputin))
		rm(outputin)
		return(forresult)
	})
	outresult <- as.data.frame(do.call(rbind, outputout))
	rm(outputout)
	return(outresult)

})

rdfphage <- as.data.frame(do.call(rbind, rout))

# Check the results
ddply(rdfphage, c("PatientID", "Location", "TimePoint"), summarize, sum = sum(as.numeric(PhageAbundance)))

rdfphage$combophage <- paste(rdfphage$from, rdfphage$PatientID, rdfphage$Location, rdfphage$TimePoint, sep = "__")
rdfphage <- rdfphage[-c(1:4)]

rout <- lapply(unique(uniquebacteriagraph$PatientID), function(i) {

	outputout <- lapply(unique(uniquebacteriagraph$TimePoint), function(t) {

		outputin <- lapply(unique(as.data.frame(uniquebacteriagraph[c(uniquebacteriagraph$PatientID %in% i & uniquebacteriagraph$TimePoint %in% t),])$Location), function(j) {
			print(c(i, t, j))
			subsetdfin <- as.data.frame(uniquebacteriagraph[c(uniquebacteriagraph$PatientID %in% i & uniquebacteriagraph$TimePoint %in% t & uniquebacteriagraph$Location %in% j),])
			if (sum(subsetdfin$BacteriaAbundance) >= phageminseq) {
				subsetdfin$BacteriaAbundance <- c(rrarefy(subsetdfin$BacteriaAbundance, sample = bacminseq))
				return(subsetdfin)
			} else {
				NULL
			}
		})
		forresult <- as.data.frame(do.call(rbind, outputin))
		rm(outputin)
		return(forresult)
	})
	outresult <- as.data.frame(do.call(rbind, outputout))
	rm(outputout)
	return(outresult)

})

rdfbacteria <- as.data.frame(do.call(rbind, rout))

ddply(rdfbacteria, c("PatientID", "Location", "TimePoint"), summarize, sum = sum(as.numeric(BacteriaAbundance)))

rdfbacteria$combobacteria <- paste(rdfbacteria$to, rdfbacteria$PatientID, rdfbacteria$Location, rdfbacteria$TimePoint, sep = "__")
rdfbacteria <- rdfbacteria[-c(1:4)]

# Merge the subsampled abundances back into the original file
totalgraphcombo <- totalgraph
totalgraphcombo$combophage <- paste(totalgraphcombo$from, totalgraphcombo$PatientID, totalgraphcombo$Location, totalgraphcombo$TimePoint, sep = "__")
totalgraphcombo$combobacteria <- paste(totalgraphcombo$to, totalgraphcombo$PatientID, totalgraphcombo$Location, totalgraphcombo$TimePoint, sep = "__")
totalgraphcombo <- totalgraphcombo[-c(1:7)]

format(object.size(totalgraphcombo), units = "MB")
format(object.size(rdfphage), units = "KB")

totalgraphmerge <- merge(totalgraphcombo, rdfphage, by = "combophage")
totalgraphmerge <- merge(totalgraphmerge, rdfbacteria, by = "combobacteria")

# Remove those without bacteria or phage nodes after subsampling
# Zero here means loss of the node
rdf <- totalgraphmerge[!c(totalgraphmerge$PhageAbundance == 0 | totalgraphmerge$BacteriaAbundance == 0),]
# Calculate edge values from nodes
rdf$edge <- log10(rdf$PhageAbundance * rdf$BacteriaAbundance) + 0.0001
# Parse the values again
rdf <- cbind(as.data.frame(str_split_fixed(rdf$combobacteria, "__", 4)), rdf)
rdf <- cbind(as.data.frame(str_split_fixed(rdf$combophage, "__", 4)), rdf)
rdf <- rdf[-c(2:4)]
rdf <- rdf[-c(6:7)]
colnames(rdf) <- c("from", "to", "PatientID", "Location", "TimePoint", "PhageAbundance", "BacteriaAbundance", "edge")

# Make a list of subgraphs for each of the samples
# This will be used for diversity, centrality, etc
routdiv <- lapply(unique(rdf$PatientID), function(i) {
	outtime <- lapply(unique(rdf$TimePoint), function(t) {
		subsetdfout <- as.data.frame(rdf[c(rdf$PatientID %in% i & rdf$TimePoint %in% t),])
		outputin <- lapply(unique(subsetdfout$Location), function(j) {
			subsetdfin <- subsetdfout[c(subsetdfout$Location %in% j),]
			lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = TRUE)
			E(lapgraph)$weight <- subsetdfin[,c("edge")]
			print(as.character(j))
			V(lapgraph)$location <- as.character(j)
			V(lapgraph)$patientid <- i
			V(lapgraph)$timepoint <- t
			return(lapgraph)
		})
		return(outputin)
	})
	return(outtime)
})

routcentral <- lapply(c(1:length(routdiv)), function(i) {
	listelementout <- routdiv[[ i ]]
	outputout <- lapply(c(1:length(listelementout)), function(k) {
		listelement <- listelementout[[ k ]]
		outputin <- lapply(c(1:length(listelement)), function(j) {
			listgraph <- listelement[[ j ]]
			patient <- unique(V(listgraph)$patientid)
			location <- unique(V(listgraph)$location)
			Timepoint <- as.numeric(unique(V(listgraph)$timepoint))
			print(c(patient, location, Timepoint))
			centraldf <- as.data.frame(alpha_centrality(listgraph, weights = E(listgraph)$weight))
			colnames(centraldf) <- "acentrality"
			
			pagerank <- as.data.frame(page_rank(listgraph, weights = E(listgraph)$weight, directed = FALSE)$vector)
			colnames(pagerank) <- "page_rank"
			pagerank$label <- rownames(pagerank)
	
			diversitydf <- as.data.frame(igraph::diversity(graph = listgraph, weights = E(listgraph)$weight))
			centraldf$label <- rownames(centraldf)
			colnames(diversitydf) <- "entropy"
			diversitydf$label <- rownames(diversitydf)
			centraldf <- merge(centraldf, diversitydf, by = "label")
			centraldf <- merge(centraldf, pagerank, by = "label")
			centraldf$subject <- patient
			centraldf$Location <- location
			centraldf$TimePoint <- Timepoint
			return(centraldf)
		})
		forresult <- as.data.frame(do.call(rbind, outputin))
		return(forresult)
	})
	outresult <- as.data.frame(do.call(rbind, outputout))
	return(outresult)
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

routham <- mclapply(c(1:length(routdiv)), function(i) {
	listelement1 <- routdiv[[ i ]]
	if(length(listelement1) != 0) {
	outputin <- lapply(c(1:length(listelement1)), function(j) {
		listgraph1 <- listelement1[[ j ]]
		if(length(listgraph1) != 0) {
		outputmid <- lapply(c(1:length(listgraph1)), function(k) {
			listgraphfin1 <- listgraph1[[ k ]]
			if(length(listgraphfin1) != 0) {
			outdf1 <- lapply(c(1:length(routdiv)), function(l) {
				listelement2 <- routdiv[[ l ]]
				if(length(listelement2) != 0) {
				outdf2 <- lapply(c(1:length(listelement2)), function(m) {
					listgraph2 <- listelement2[[ m ]]
					if(length(listgraph2) != 0) {
					outdf2out <- lapply(c(1:length(listgraph2)), function(n) {
						print(c(i,j,k,l,m,n))
						listgraphfin2 <- listgraph2[[ n ]]
						if(length(listgraphfin2) != 0) {
						patient1 <- unique(V(listgraphfin1)$patientid)
						patient2 <- unique(V(listgraphfin2)$patientid)
						patient1tp <- paste(
							unique(V(listgraphfin1)$patientid),
							unique(V(listgraphfin1)$location),
							unique(V(listgraphfin1)$timepoint), sep = "_")
						patient2tp <- paste(
							unique(V(listgraphfin2)$patientid),
							unique(V(listgraphfin2)$location),
							unique(V(listgraphfin2)$timepoint), sep = "_")
						hdistval <- hamming_distance(listgraphfin1, listgraphfin2)
						outdftop <- data.frame(patient1, patient2, patient1tp, patient2tp, hdistval)
						return(outdftop)
						} else {
							return(NULL)
						}
					})
					outmid2 <- as.data.frame(do.call(rbind, outdf2out))
					return(outmid2)
					} else {
						return(NULL)
					}
				})
				inresulttop <- as.data.frame(do.call(rbind, outdf2))
				return(inresulttop)
				} else {
					return(NULL)
				}
			})
			inresultmiddle <- as.data.frame(do.call(rbind, outdf1))
			return(inresultmiddle)
			} else {
				return(NULL)
			}
		})
		outputmidoutput <- as.data.frame(do.call(rbind, outputmid))
		return(outputmidoutput)
		} else {
			return(NULL)
		}
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
	} else {
		return(NULL)
	}
}, mc.cores = 4)

# save(routham, file = "./skinbetadivbackup.Rdata")

load(file = "./skinbetadivbackup.Rdata")

# routham <- as.data.frame(do.call(rbind, routham))
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
acentral_master <- plot_grid(
	alpha_centrality_boxplot_all,
	alpha_centrality_boxplot_moist,
	alpha_centrality_boxplot_occ,
	labels = c("A", "F", "K"),
	ncol = 1)

pagerank_master <- plot_grid(
	pagerank_boxplot_all,
	pagerank_boxplot_moist,
	pagerank_boxplot_occ,
	labels = c("B", "G", "L"),
	ncol = 1)

diversity_master <- plot_grid(
	diversity_boxplot_all,
	diversity_boxplot_moist,
	diversity_boxplot_occ,
	labels = c("C", "H", "M"),
	ncol = 1)

significance_master <- plot_grid(
	plotdiffs_all,
	plotdiffs_moist,
	plotdiffs_occ,
	labels = c("D", "I", "N"),
	ncol = 1)

nmdb_master <- plot_grid(
	plotnmds_location,
	plotnmds_moist,
	plotnmds_occ,
	labels = c("E", "J", "O"),
	ncol = 1)

threeplots <- plot_grid(acentral_master, pagerank_master, diversity_master, significance_master, nmdb_master, nrow = 1)

interpersonalplot <- plot_grid(intrabetadiv_personal, intrabetadiv_location, nrow = 1, labels = c("A", "B"))

pdf("./figures/skinplotresults.pdf", width = 16, height = 8)
	threeplots
dev.off()

pdf("./figures/skininterpersonal.pdf", width = 8, height = 4)
	interpersonalplot
dev.off()
