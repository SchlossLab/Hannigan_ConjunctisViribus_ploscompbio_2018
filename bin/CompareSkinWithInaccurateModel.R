##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "scales", "plyr", "cowplot", "vegan", "reshape2", "parallel", "stringr")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)
library("tidyr")
library("dplyr")

itrnum <- 5

##############################
# Run Analysis & Save Output #
##############################
# Import graphs into a list
skinsites <- c("Ax", "Ac", "Pa", "Tw", "Um", "Fh", "Ra")
timepoints <- c("TP2", "TP3")
subjectarray <- paste("skin", c(1:20), sep = "_")

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

# Remove the filtered out phage OGUs
filterlist <- read.delim(
  file = "./data/contigclustersidentity/bacterialremoval-clusters-list.tsv",
  header = FALSE)

totalgraph <- totalgraph[!c(totalgraph$from %in% filterlist$V1),]

autoskindata <- function(x, prob) {
	write("Starting subroutine...", stdout())
	skingraph <- x
	# Can introduce noise by removing random rows as a percent
	skingraph <- skingraph %>%
		group_by(PatientID, TimePoint, Location) %>%
		sample_frac(size = prob) %>%
		as.data.frame()

	write("Noise introduced...", stdout())

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

	# Make a data frame with the occlusion and moisture status sort
	# that I can merge it in with my existing data.
	moisture <- c("Moist", "IntMoist", "IntMoist", "Moist", "Moist", "Sebaceous", "Sebaceous")
	occlusion <- c("Occluded", "IntOccluded", "Exposed", "Occluded", "Occluded", "Exposed", "Occluded")
	locationmetadata <- data.frame(skinsites, moisture, occlusion)
	
	rcentralmerge <- merge(rcentraldf, locationmetadata, by.x = "location", by.y = "skinsites")
	
	# Moisture Levels
	
	moistsig <- melt(pairwise.wilcox.test(x = rcentralmerge$ec, g = rcentralmerge$moisture)$p.value)
	moistsig$class <- "moist"
	occsig <- melt(pairwise.wilcox.test(x = rcentralmerge$ec, g = rcentralmerge$occlusion)$p.value)
	occsig$class <- "occ"
	totalsig <- rbind(moistsig, occsig)
	return(totalsig)
}

skin_ii <- do.call(rbind, lapply(1 - .1 * c(1:4), function(j) {
	skiniterations <- do.call(rbind, parallel::mclapply(1:itrnum, mc.cores = 5, function(i) {
		write(i, stdout())
		outval <- autoskindata(totalgraph, prob = j)
		outdf <- data.frame(
			"prob" = j,
			"iteration" = i,
			"Var1" = outval$Var1,
			"Var2" = outval$Var2,
			"pvalue" = outval$value,
			"class" = outval$class)
		return(outdf)
	}))
	return(skiniterations)
}))


skin_iii <- skin_ii %>%
	group_by(prob, Var1, Var2) %>%
	summarize(mp = mean(pvalue), sp = sd(pvalue)/sqrt(length(pvalue)), class = unique(class)) %>%
	as.data.frame()

skin_iii$Var <- paste(skin_iii$Var1, skin_iii$Var2, sep = "-")

skin_iii <- skin_iii[,-c(2,3)]

skin_iii <- skin_iii[complete.cases(skin_iii), ]

# Run the total plot as well
skingraphdf <- data.frame()

for (i in skinsites) {
	for (j in timepoints) {
		for (k in subjectarray) {
			print(i)
			print(k)
			print(i)
			filename <- paste("./data/skingraph-", i, "-", k, "-", j, ".Rdata", sep = "")
			load(file = filename)
			skingraphdf <- rbind(skingraphdf, sampletable)
			rm(sampletable)
		}
	}
}

rm(i)
rm(j)
rm(k)

# Remove the filtered out phage OGUs
skingraphdf <- skingraphdf[!c(skingraphdf$from %in% filterlist$V1),]

real_edges <- nrow(totalgraph)
all_edges <- nrow(skingraphdf)
pedge <- all_edges/real_edges

salli <- autoskindata(skingraphdf, prob = 1)

salli$Var <- paste(salli$Var1, salli$Var2, sep = "-")

salldf <- data.frame(
	prob = rep(pedge, nrow(salli)),
	mp = salli$value,
	sp = rep(pedge, nrow(salli)),
	class = salli$class,
	Var = salli$Var)

salldf <- salldf[complete.cases(salldf), ]

sallm <- rbind(skin_iii, salldf)

skin_plot <- ggplot(sallm, aes(x = prob, y = mp, group = Var, colour = Var)) +
	theme_classic() +
    geom_errorbar(aes(ymin=mp-sp, ymax=mp+sp), width=.01) +
    geom_line(alpha = 0.25) +
    geom_point() +
    geom_hline(yintercept = 0.05, color="blue", linetype="dashed") +
    scale_x_reverse() +
    xlab("Percent Edges Randomly Kept in Graph") +
    ylab("Skin Eigen Centrality P-value\n(log10 Scale)") +
    scale_y_log10(limits = c(1e-10, 1)) +
    facet_grid(. ~ class) +
    scale_colour_manual(values = wes_palette("Darjeeling", 6, type = "continuous"), name = "Sites")

pdf("./figures/skin_site_comparison_noise.pdf", width = 10, height = 6)
	skin_plot
dev.off()
