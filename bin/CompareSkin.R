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
uniquephagegraph <- unique(totalgraph[-c(2,7:9)])
phageminseq <- quantile(ddply(uniquephagegraph, c("PatientID", "Location", "TimePoint"), summarize, sum = sum(as.numeric(PhageAbundance)))$sum, 0.05)
print(format(object.size(uniquephagegraph), units = "MB"))

uniquebacteriagraph <- unique(totalgraph[-c(1,6,7,9)])
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
totalgraphcombo <- totalgraphcombo[-c(1:9)]

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

routcentral <- lapply(routdiv, function(i) {
	outputout <- lapply(i, function(k) {
		outputin <- lapply(k, function(j) {
			listgraph <- j

			ec <- centr_eigen(listgraph)$centralization

			bt <- centr_betw(listgraph)$centralization

			cl <- centr_clo(listgraph)$centralization

			dg <- centr_degree(listgraph)$centralization

			di <- diameter(listgraph)

			patient <- unique(V(listgraph)$patientid)
			tp <- unique(V(listgraph)$timepoint)
			diettype <- unique(V(listgraph)$location)

			centraldf <- c(patient, tp, diettype, ec, bt, cl, dg, di)
			return(centraldf)
		})
		forresult <- as.data.frame(do.call(rbind, outputin))
		return(forresult)
	})
	outresult <- as.data.frame(do.call(rbind, outputout))
	return(outresult)
})

rcentraldf <- as.data.frame(do.call(rbind, routcentral))
colnames(rcentraldf) <- c("patient", "time", "location", "ec", "bt", "cl", "dg", "di")

rcentraldf$ec <- as.numeric(as.character(rcentraldf$ec))
rcentraldf$bt <- as.numeric(as.character(rcentraldf$bt))
rcentraldf$cl <- as.numeric(as.character(rcentraldf$cl))
rcentraldf$dg <- as.numeric(as.character(rcentraldf$dg))
rcentraldf$di <- as.numeric(as.character(rcentraldf$di))


ggplot(rcentraldf, aes(x = factor(location), y = cl)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Alpha Centrality") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	)

pairwise.wilcox.test(x = rcentraldf$ec, g = rcentraldf$location)

### Differences by broader location classification ###

# Make a data frame with the occlusion and moisture status sort
# that I can merge it in with my existing data.
moisture <- c("Moist", "IntMoist", "IntMoist", "Moist", "Moist", "Sebaceous", "Sebaceous")
occlusion <- c("Occluded", "IntOccluded", "Exposed", "Occluded", "Occluded", "Exposed", "Occluded")
locationmetadata <- data.frame(skinsites, moisture, occlusion)

rcentralmerge <- merge(rcentraldf, locationmetadata, by.x = "location", by.y = "skinsites")

# Moisture Levels

box_moist <- ggplot(rcentralmerge, aes(x = factor(moisture), y = cl)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Eigen Centrality") +
	xlab("") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	) +
	ylim(0, 0.005) +
	geom_segment(x = 1, xend = 2, y = 0.0045, yend = 0.0045) +
	annotate("text", x = 1.5, y = 0.00455, label = "*", size = 6) +
	geom_segment(x = 1, xend = 3, y = 0.0048, yend = 0.0048) +
	annotate("text", x = 1.5, y = 0.00485, label = "*", size = 6)

moistsig <- melt(pairwise.wilcox.test(x = rcentralmerge$ec, g = rcentralmerge$moisture)$p.value)

# Occlusion Status

box_occ <- ggplot(rcentralmerge, aes(x = factor(occlusion), y = cl)) +
	theme_classic() +
	geom_boxplot(notch = TRUE, fill="gray") +
	ylab("Eigen Centrality") +
	xlab("") +
	theme(
	    axis.line.x = element_line(colour = "black"),
	    axis.line.y = element_line(colour = "black")
	) +
	ylim(0, 0.005) +
	geom_segment(x = 2, xend = 3, y = 0.0045, yend = 0.0045) +
	annotate("text", x = 2.5, y = 0.00455, label = "*", size = 6) +
	geom_segment(x = 1, xend = 3, y = 0.0048, yend = 0.0048) +
	annotate("text", x = 2, y = 0.00485, label = "*", size = 6)

occsig <- melt(pairwise.wilcox.test(x = rcentralmerge$cl, g = rcentralmerge$occlusion)$p.value)

boxsig <- rbind(moistsig, occsig)

# Beta diversity between graphs
# Proportion of shared edges between graphs

rcen <- lapply(routdiv, function(i) {
	outputout <- lapply(i, function(k) {
		outputin <- lapply(k, function(j) {
			centraldf <- as.data.frame(eigen_centrality(j)$vector)
			colnames(centraldf) <- "ecen"
			centraldf$names <- row.names(centraldf)
			centraldf$patient <- unique(V(j)$patientid)
			centraldf$Timepoint <- unique(V(j)$timepoint)
			centraldf$location <- unique(V(j)$location)
			print(c(unique(V(j)$patientid), unique(V(j)$timepoint), unique(V(j)$location)))
			return(centraldf)
		})
		forresult <- as.data.frame(do.call(rbind, outputin))
		return(forresult)
	})
	outresult <- as.data.frame(do.call(rbind, outputout))
	return(outresult)
})
rcdf <- as.data.frame(do.call(rbind, rcen))
rcast <- dcast(rcdf, patient + Timepoint + location ~ names, value.var = "ecen")
rcast[is.na(rcast)] <- 0
rownames(rcast) <- paste(rcast$patient, rcast$Timepoint, rcast$location, sep = "_")
rcast <- rcast[,-c(1:3)]
rdistskin <- vegdist(rcast, method = "bray")

ORD_NMDS <- metaMDS(comm = rdistskin, k=2, trymax = 50)
ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
ORD_FIT$SampleID <- rownames(ORD_FIT)
# Get metadata
ORD_FIT <- cbind(ORD_FIT, as.data.frame(str_split_fixed(ORD_FIT$SampleID, "_", 3)))

ORD_FIT <- merge(ORD_FIT, locationmetadata, by.x = "V3", by.y = "skinsites")

plotnmds_loc <- ggplot(ORD_FIT, aes(x=MDS1, y=MDS2, colour=factor(V3))) +
    theme_classic()  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
    geom_point() +
    scale_color_manual(values = c(wes_palette("Darjeeling"), wes_palette("Darjeeling2")))

plotnmds_moist <- ggplot(ORD_FIT, aes(x=MDS1, y=MDS2, colour=factor(moisture))) +
    theme_classic()  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
    geom_point() +
    scale_color_manual(values = wes_palette("Darjeeling"), name = "Environment")

plotnmds_occ <- ggplot(ORD_FIT, aes(x=MDS1, y=MDS2, colour=factor(occlusion))) +
    theme_classic()  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
    geom_point() +
    scale_color_manual(values = wes_palette("Darjeeling"), name = "Environment")

anosim(rdistskin, ORD_FIT$V3)

# Calculate statistical significance
routmerge <- as.data.frame(row.names(as.matrix(rdistskin)))
colnames(routmerge) <- "SampleID"
routmerge <- cbind(routmerge, as.data.frame(str_split_fixed(routmerge$SampleID, "_", 3)))
routmerge$order <- str_pad(rownames(routmerge), 4, pad = "0")
routmerge <- merge(routmerge, locationmetadata, by.x = "V3", by.y = "skinsites")
routmerge <- routmerge[order(routmerge$order),]

mod <- betadisper(d = rdistskin, routmerge[,"V3"])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
moddf <- moddf[order(moddf$diff, decreasing = TRUE),]
moddf$comparison <- factor(moddf$comparison, levels = moddf$comparison)
moddf$significance <- ifelse(moddf[,"p adj"] < 0.05, "Sig", "NonSig")
limits <- aes(ymax = upr, ymin=lwr)
plotdiffs_loc <- ggplot(moddf, aes(y=diff, x=comparison, colour = significance)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
	scale_color_manual(values = c("Grey", "Tomato4"))


mod <- betadisper(d = rdistskin, routmerge[,"moisture"])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
moddf <- moddf[order(moddf$diff, decreasing = TRUE),]
moddf$comparison <- factor(moddf$comparison, levels = moddf$comparison)
moddf$significance <- ifelse(moddf[,"p adj"] < 0.05, "Significant", "Insignificant")
limits <- aes(ymax = upr, ymin=lwr)

plotdiffs_moist <- ggplot(moddf, aes(y=diff, x=comparison, colour = significance)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
	scale_color_manual(values = c("Tomato4", "Grey"), name = "")


mod <- betadisper(d = rdistskin, routmerge[,"occlusion"])
anova(mod)
permutest(mod, pairwise = TRUE)
mod.HSD <- TukeyHSD(mod)

moddf <- as.data.frame(mod.HSD$group)
moddf$comparison <- row.names(moddf)
moddf <- moddf[order(moddf$diff, decreasing = TRUE),]
moddf$comparison <- factor(moddf$comparison, levels = moddf$comparison)
moddf$significance <- ifelse(moddf[,"p adj"] < 0.05, "Significant", "Insignificant")
limits <- aes(ymax = upr, ymin=lwr)

plotdiffs_occ <- ggplot(moddf, aes(y=diff, x=comparison, colour = significance)) +
    theme_classic() +
    geom_pointrange(limits) +
    geom_hline(yintercept=0, linetype = "dashed") +
    coord_flip() +
    ylab("Differences in Mean Levels of Group") +
    xlab("")  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
	scale_color_manual(values = c("Grey", "Tomato4"), name = "")

moist_nmds <- plot_grid(plotnmds_moist, plotdiffs_moist, rel_heights = c(2,1), ncol = 1, labels = c("C", "E"))
occ_nmds <- plot_grid(plotnmds_occ, plotdiffs_occ, rel_heights = c(2,1), ncol = 1, labels = c("D", "F"))

# save(routham, file = "./skinbetadivbackup.Rdata")

# load(file = "./skinbetadivbackup.Rdata")

finalplot <- plot_grid(box_moist, box_occ, moist_nmds, occ_nmds, rel_heights = c(1, 2), nrow = 2, labels = c("A", "B"))

pdf("./figures/skinplotresults.pdf", width = 10, height = 10)
	finalplot
dev.off()

# Print the stats
write.table(boxsig, file = "./rtables/skinboxsig.tsv", quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)

