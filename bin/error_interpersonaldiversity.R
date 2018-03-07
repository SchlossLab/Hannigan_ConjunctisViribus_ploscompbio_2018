##################
# Load Libraries #
##################
gcinfo(FALSE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "vegan", "reshape2", "stringr")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)
library("tidyr")
library("dplyr")
library("parallel")

itrnum <- 5

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
	toInt(z.Length) AS PhageLength,
	toInt(e.Abundance) AS BacteriaAbundance,
	toInt(a.Length) AS BacteriaLength;
"

sampletable <- as.data.frame(cypher(graph, sampleidquery))

# Correct the lengths
sampletable$PhageAbundance <- round(1e7 * sampletable$PhageAbundance / sampletable$PhageLength)
sampletable$BacteriaAbundance <- round(1e7 * sampletable$BacteriaAbundance / sampletable$BacteriaLength)
sampletable <- sampletable[,-9]
sampletable <- sampletable[,-7]

head(sampletable)

# Remove the filtered out phage OGUs
filterlist <- read.delim(
  file = "./data/contigclustersidentity/bacterialremoval-clusters-list.tsv",
  header = FALSE)

sampletable <- sampletable[!c(sampletable$from %in% filterlist$V1),]

autodietdata <- function(x, prob) {
	dietgraph <- x
	# Can introduce noise by removing random rows as a percent
	dietgraph <- dietgraph %>%
		group_by(PatientID, TimePoint) %>%
		sample_frac(size = prob) %>%
		as.data.frame()

	# get subsampling depth
	phageminseq <- min(ddply(dietgraph, c("PatientID", "TimePoint"), summarize, sum = sum(PhageAbundance))$sum)
	bacminseq <- min(ddply(dietgraph, c("PatientID", "TimePoint"), summarize, sum = sum(BacteriaAbundance))$sum)
	
	# Rarefy each sample using sequence counts
	rout <- lapply(unique(dietgraph$PatientID), function(i) {
		subsetdfout <- as.data.frame(dietgraph[c(dietgraph$PatientID %in% i),])
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
	
	##### Eigen Vector Centrality #####
	rcen <- lapply(c(1:length(routdiv)), function(i) {
		listelement <- routdiv[[ i ]]
		outputin <- lapply(c(1:length(listelement)), function(j) {
			listgraph <- listelement[[ j ]]
			centraldf <- as.data.frame(eigen_centrality(listgraph)$vector)
			colnames(centraldf) <- "ecen"
			centraldf$names <- row.names(centraldf)
	
			centraldf$patient <- unique(V(listgraph)$patientid)
			centraldf$tp <- unique(V(listgraph)$timepoint)
			centraldf$diettype <- unique(V(listgraph)$diet)
	
			return(centraldf)
		})
		forresult <- as.data.frame(do.call(rbind, outputin))
		return(forresult)
	})
	rcdf <- as.data.frame(do.call(rbind, rcen))
	rcast <- dcast(rcdf, patient + tp ~ names, value.var = "ecen")
	rcast[is.na(rcast)] <- 0
	rownames(rcast) <- paste(rcast$patient, rcast$tp, sep = "_")
	rcast <- rcast[!c(rcast$patient == 2012),]
	rcast <- rcast[,-c(1:2)]
	
	rdist <- vegdist(rcast, method = "bray")
	rdm <- melt(as.matrix(rdist))
	rm <- cbind(rdm, as.data.frame(str_split_fixed(rdm$Var1, "_", 2)))
	rm <- cbind(rm, as.data.frame(str_split_fixed(rm$Var2, "_", 2)))
	rm <- rm[,-c(1:2)]
	colnames(rm) <- c("ec", "patient1", "time1", "patient2", "time2")
	rm <- rm[!c(rm$ec == 0),]
	
	rm$class <- ifelse(rm$patient1 == rm$patient2, "Intrapersonal", "Interpersonal")
	
	ravg <- ddply(rm, c("patient1", "class"), summarize, avg = mean(ec))
	ravgslope <- lapply(unique(ravg$patient1), function(i) {
		y <- ravg[c(ravg$class %in% "Intrapersonal" & ravg$patient1 %in% i), "avg"] - ravg[c(ravg$class %in% "Interpersonal" & ravg$patient1 %in% i), "avg"]
		return(data.frame(i, y))
	})
	ravgslope <- do.call(rbind, ravgslope)
	sum(c(ravgslope$y <= 0) + 0) / length(ravgslope$y)
	
	# Statistical significance
	chg <- ravgslope$y
	pdf <- density(chg)
	fx <- approxfun(pdf$x, pdf$y, yleft=0, yright=0)
	cdfdiet <- integrate(fx, -Inf, 0)
	cdfdiet
	
	pdietpvalue <- wilcox.test(data = ravg, avg ~ class, paired = TRUE)$p.value
		
	## Ordination ###
	ORD_NMDS <- metaMDS(comm = rdist, k=2)
	ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
	ORD_FIT$SampleID <- rownames(ORD_FIT)
	# Get metadata
	ORD_FIT <- cbind(ORD_FIT, as.data.frame(str_split_fixed(ORD_FIT$SampleID, "_", 2)))
	
	anosimstat <- anosim(rdist, ORD_FIT$V1)

	return(list(pdietpvalue, anosimstat$signif))
}

# Get a p-value to plot to show the lack of change in significance
diet_ii <- do.call(rbind, lapply(1 - .1 * c(1:4), function(j) {
	dietiterations <- do.call(rbind, lapply(1:itrnum, function(i) {
		write(i, stdout())
		outval <- autodietdata(sampletable, prob = j)
		outdf <- data.frame("prob" = j, "iteration" = i, "pvalue" = outval[[1]], "anosimpval" = outval[[2]])
		return(outdf)
	}))
	return(dietiterations)
}))

diet_iii <- diet_ii %>%
	group_by(prob) %>%
	summarize(mp = mean(pvalue), ma = mean(anosimpval), sp = sd(pvalue)/sqrt(length(pvalue)), sa = sd(anosimpval)/sqrt(length(anosimpval))) %>%
	as.data.frame()

# Get all of the possible edges now
sampleidquery <- "
MATCH
	(x:SRP002424)-->(y)-[d]->(z:Phage),
	(a:Bacterial_Host)<-[e]-(b)<--(x:SRP002424),
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
	toInt(z.Length) AS PhageLength,
	toInt(e.Abundance) AS BacteriaAbundance,
	toInt(a.Length) AS BacteriaLength;
"

sampletableall <- as.data.frame(cypher(graph, sampleidquery))

# Correct the lengths
sampletableall$PhageAbundance <- round(1e7 * sampletableall$PhageAbundance / sampletableall$PhageLength)
sampletableall$BacteriaAbundance <- round(1e7 * sampletableall$BacteriaAbundance / sampletableall$BacteriaLength)
sampletableall <- sampletableall[,-9]
sampletableall <- sampletableall[,-7]

head(sampletableall)

# Remove the filtered out phage OGUs
filterlist <- read.delim(
  file = "./data/contigclustersidentity/bacterialremoval-clusters-list.tsv",
  header = FALSE)

sampletableall <- sampletableall[!c(sampletableall$from %in% filterlist$V1),]

real_edges <- nrow(sampletable)
all_edges <- nrow(sampletableall)
pedge <- all_edges/real_edges

dalli <- autodietdata(sampletableall, prob = 1)

dalldf <- data.frame(prob = pedge, mp = dalli[[1]], ma = dalli[[2]], sp = 0, sa = 0)

dallm <- rbind(diet_iii, dalldf)

diet_plot <- ggplot(dallm, aes(x = prob, y = mp)) +
	theme_classic() +
    geom_errorbar(aes(ymin=mp-sp, ymax=mp+sp), width=.01) +
    geom_line(colour = "black", alpha = 0.25) +
    geom_point() +
    scale_y_log10(limits = c(1e-2, 1)) +
    geom_hline(yintercept = 0.05, color="blue", linetype="dashed") +
    scale_x_reverse() +
    xlab("Percent Edges Randomly Kept in Graph") +
    ylab("Diet Paired P-value\n(log10 scale)")

diet_anosim_plot <- ggplot(dallm, aes(x = prob, y = ma)) +
	theme_classic() +
    geom_errorbar(aes(ymin=ma-sa, ymax=ma+sa), width=.01) +
    geom_point() +
    geom_line(colour = "black", alpha = 0.25) +
    scale_y_log10(limits = c(1e-4, 1)) +
    geom_hline(yintercept = 0.05, color="blue", linetype="dashed") +
    scale_x_reverse() +
    xlab("Percent Edges Randomly Kept in Graph") +
    ylab("Diet Paired P-value\n(log10 scale)")




##############
# Skin Graph #
##############
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

	# Correct the lengths
	skingraph$PhageAbundance <- round(1e7 * skingraph$PhageAbundance / skingraph$PhageLength)
	skingraph$BacteriaAbundance <- round(1e7 * skingraph$BacteriaAbundance / skingraph$BacteriaLength)
	skingraph <- skingraph[,-9]
	skingraph <- skingraph[,-7]
	
	# See the object size
	format(object.size(skingraph), units = "MB")
	
	# Run subsampling
	uniquephagegraph <- unique(skingraph[-c(2,7)])
	phageminseq <- quantile(ddply(uniquephagegraph, c("PatientID", "Location", "TimePoint"), summarize, sum = sum(as.numeric(PhageAbundance)))$sum, 0.05)
	print(format(object.size(uniquephagegraph), units = "MB"))
	
	uniquebacteriagraph <- unique(skingraph[-c(1,6)])
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
	skingraphcombo <- skingraph
	skingraphcombo$combophage <- paste(skingraphcombo$from, skingraphcombo$PatientID, skingraphcombo$Location, skingraphcombo$TimePoint, sep = "__")
	skingraphcombo$combobacteria <- paste(skingraphcombo$to, skingraphcombo$PatientID, skingraphcombo$Location, skingraphcombo$TimePoint, sep = "__")
	skingraphcombo <- skingraphcombo[-c(1:7)]
	
	format(object.size(skingraphcombo), units = "MB")
	format(object.size(rdfphage), units = "KB")
	
	skingraphmerge <- merge(skingraphcombo, rdfphage, by = "combophage")
	skingraphmerge <- merge(skingraphmerge, rdfbacteria, by = "combobacteria")
	
	# Remove those without bacteria or phage nodes after subsampling
	# Zero here means loss of the node
	rdf <- skingraphmerge[!c(skingraphmerge$PhageAbundance == 0 | skingraphmerge$BacteriaAbundance == 0),]
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
		print(i)
		outtime <- lapply(unique(rdf$TimePoint), function(t) {
			print(t)
			subsetdfout <- as.data.frame(rdf[c(rdf$PatientID %in% i & rdf$TimePoint %in% t),])
			outputin <- lapply(unique(subsetdfout$Location), function(j) {
				print(j)
				subsetdfin <- subsetdfout[c(subsetdfout$Location %in% j),]
				lapgraph <- graph_from_data_frame(subsetdfin[,c("to", "from")], directed = FALSE)
				E(lapgraph)$weight <- subsetdfin[,c("edge")]
				print(as.character(j))
				V(lapgraph)$location <- as.character(j)
				V(lapgraph)$patientid <- as.character(i)
				print(unique(V(lapgraph)$patientid))
				V(lapgraph)$timepoint <- t
				return(lapgraph)
			})
			return(outputin)
		})
		return(outtime)
	})
	
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
	
	rdm <- melt(as.matrix(rdistskin))
	rm <- cbind(rdm, as.data.frame(str_split_fixed(rdm$Var1, "_", 4)))
	rm <- cbind(rm, as.data.frame(str_split_fixed(rm$Var2, "_", 4)))
	rm <- rm[,-c(1:2)]
	rm <- rm[,-c(2,6)]
	colnames(rm) <- c("ec", "patient1", "time1", "location1", "patient2", "time2", "location2")
	rm <- rm[!c(rm$ec == 0),]
	
	moisture <- c("Moist", "IntMoist", "IntMoist", "Moist", "Moist", "Sebaceous", "Sebaceous")
	occlusion <- c("Occluded", "IntOccluded", "Exposed", "Occluded", "Occluded", "Exposed", "Occluded")
	locationmetadata <- data.frame(skinsites, moisture, occlusion)
	
	# Interpersonal Differences
	rm[c(rm$patient1 == rm$patient2 & rm$location1 == rm$location2), "class"] <- "Intrapersonal"
	rm[c(rm$patient1 != rm$patient2 & rm$time1 == rm$time2 & rm$location1 == rm$location2), "class"] <- "Interpersonal"
	rm <- rm[complete.cases(rm),]
	
	ravg <- ddply(rm, c("patient1", "class", "location1"), summarize, avg = mean(ec))
	counta <- ddply(ravg, c("patient1", "location1"), summarize, count = length(unique(class)))
	counta <- counta[c(counta$count == 2),]
	ravg <- merge(ravg, counta, by = c("patient1", "location1"))
	ravg$merged <- paste(ravg$patient1, ravg$location1, sep = "")
	ravgslope <- lapply(unique(ravg$merged), function(i) {
		y <- ravg[c(ravg$class %in% "Intrapersonal" & ravg$merged %in% i), "avg"] - ravg[c(ravg$class %in% "Interpersonal" & ravg$merged %in% i), "avg"]
		return(data.frame(i, y))
	})
	ravgslope <- do.call(rbind, ravgslope)
	
	chg <- ravgslope$y
	pdf <- density(chg)
	fx <- approxfun(pdf$x, pdf$y, yleft=0, yright=0)
	cdfskin <- integrate(fx, -Inf, 0)
	cdfskin
	
	pskinpvalue <- wilcox.test(data = ravg, avg ~ class, paired = TRUE)$p.value

	return(pskinpvalue)
}

# Get a p-value to plot to show the lack of change in significance
skin_ii <- do.call(rbind, lapply(1 - .1 * c(1:4), function(j) {
	skiniterations <- do.call(rbind, parallel::mclapply(1:itrnum, mc.cores = 5, function(i) {
		write(i, stdout())
		outval <- autoskindata(totalgraph, prob = j)
		outdf <- data.frame("prob" = j, "iteration" = i, "pvalue" = outval)
		return(outdf)
	}))
	return(skiniterations)
}))

skin_iii <- skin_ii %>%
	group_by(prob) %>%
	summarize(mp = mean(pvalue), sp = sd(pvalue)/sqrt(length(pvalue))) %>%
	as.data.frame()

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

salldf <- data.frame(prob = pedge, mp = salli, sp = 0)

sallm <- rbind(skin_iii, salldf)

skin_plot <- ggplot(sallm, aes(x = prob, y = mp)) +
	theme_classic() +
    geom_errorbar(aes(ymin=mp-sp, ymax=mp+sp), width=.01) +
    geom_line(colour = "black", alpha = 0.25) +
    geom_point() +
    geom_hline(yintercept = 0.05, color="blue", linetype="dashed") +
    scale_x_reverse() +
    xlab("Percent Edges Randomly Kept in Graph") +
    ylab("Skin Paired P-value\n(log10 scale)") +
    scale_y_log10(limits = c(1e-15, 1))



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

# Remove the filtered out phage OGUs
sampletable <- sampletable[!c(sampletable$from %in% filterlist$V1),]

autotwindata <- function(x, prob) {
	sampletable_twin <- x
	# Can introduce noise by removing random rows as a percent
	sampletable_twin <- sampletable_twin %>%
		group_by(PatientID, TimePoint) %>%
		sample_frac(size = prob) %>%
		as.data.frame()
	
	# get subsampling depth
	phageminseq <- min(ddply(sampletable_twin, c("PatientID", "TimePoint"), summarize, sum = sum(PhageAbundance))$sum)
	bacminseq <- min(ddply(sampletable_twin, c("PatientID", "TimePoint"), summarize, sum = sum(BacteriaAbundance))$sum)
	
	# Rarefy each sample using sequence counts
	rout <- lapply(unique(sampletable_twin$PatientID), function(i) {
		subsetdfout <- as.data.frame(sampletable_twin[c(sampletable_twin$PatientID %in% i),])
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
	
	rcen <- lapply(routdiv, function(i) {
		outputout <- lapply(i, function(k) {
			centraldf <- as.data.frame(eigen_centrality(k)$vector)
			colnames(centraldf) <- "ecen"
			centraldf$names <- row.names(centraldf)
			centraldf$patient <- unique(V(k)$patientid)
			centraldf$Timepoint <- unique(V(k)$timepoint)
			centraldf$diettype <- unique(V(k)$diet)
			print(c(unique(V(k)$patientid), unique(V(k)$timepoint)))
			return(centraldf)
		})
		outresult <- as.data.frame(do.call(rbind, outputout))
		return(outresult)
	})
	rcdf <- as.data.frame(do.call(rbind, rcen))
	rcast <- dcast(rcdf, patient + Timepoint + diettype ~ names, value.var = "ecen")
	rcast[is.na(rcast)] <- 0
	rownames(rcast) <- paste(rcast$patient, rcast$Timepoint, rcast$diettype, sep = "_")
	rcast <- rcast[,-c(1:3)]
	rdisttwin <- vegdist(rcast, method = "bray")
	
	
	rdm <- melt(as.matrix(rdisttwin))
	rm <- cbind(rdm, as.data.frame(str_split_fixed(rdm$Var1, "_", 3)))
	rm <- cbind(rm, as.data.frame(str_split_fixed(rm$Var2, "_", 3)))
	rm <- rm[,-c(1:2)]
	colnames(rm) <- c("ec", "patient1", "time1", "diet1", "patient2", "time2", "diet2")
	rm <- rm[!c(rm$ec == 0),]
	
	rm$family1 <- gsub("[TM].*", "", rm$patient1, perl = TRUE)
	rm$family2 <- gsub("[TM].*", "", rm$patient2, perl = TRUE)
	rm$person1 <- gsub("F\\d", "", rm$patient1, perl = TRUE)
	rm$person1 <- gsub("\\d", "", rm$person1, perl = TRUE)
	rm$person2 <- gsub("F\\d", "", rm$patient2, perl = TRUE)
	rm$person2 <- gsub("\\d", "", rm$person2, perl = TRUE)
	
	rm$class <- ifelse(rm$family1 == rm$family2, "Intrafamily", "Interfamily")
	
	ravg <- ddply(rm, c("patient1", "class"), summarize, avg = mean(ec))
	ravgslope <- lapply(unique(ravg$patient1), function(i) {
		y <- ravg[c(ravg$class %in% "Intrafamily" & ravg$patient1 %in% i), "avg"] - ravg[c(ravg$class %in% "Interfamily" & ravg$patient1 %in% i), "avg"]
		return(data.frame(i, y))
	})
	ravgslope <- do.call(rbind, ravgslope)
	
	chg <- ravgslope$y
	pdf <- density(chg)
	fx <- approxfun(pdf$x, pdf$y, yleft=0, yright=0)
	cdftwins <- integrate(fx, -Inf, 0)
	cdftwins
	
	ptwinpvalue <- wilcox.test(data = ravg, avg ~ class, paired = TRUE)$p.value
	
	return(ptwinpvalue)
}

# Get a p-value to plot to show the lack of change in significance
twin_ii <- do.call(rbind, lapply(1 - .1 * c(1:4), function(j) {
	twiniterations <- do.call(rbind, lapply(1:itrnum, function(i) {
		write(i, stdout())
		outval <- autotwindata(sampletable, prob = j)
		outdf <- data.frame("prob" = j, "iteration" = i, "pvalue" = outval)
		return(outdf)
	}))
	return(twiniterations)
}))

twin_iii <- twin_ii %>%
	group_by(prob) %>%
	summarize(mp = mean(pvalue), sp = sd(pvalue)/sqrt(length(pvalue))) %>%
	as.data.frame()

sampleidquery <- "
MATCH
	(x:SRP002523)-->(y)-[d]->(z:Phage),
	(a:Bacterial_Host)<-[e]-(b)<--(x:SRP002523),
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

sampletable_twin <- as.data.frame(cypher(graph, sampleidquery))

head(sampletable_twin)

# Remove the filtered out phage OGUs
sampletable_twin <- sampletable_twin[!c(sampletable_twin$from %in% filterlist$V1),]

real_edges <- nrow(sampletable)
all_edges <- nrow(sampletable_twin)
pedge <- all_edges/real_edges

talli <- autotwindata(sampletable_twin, prob = 1)

talldf <- data.frame(prob = pedge, mp = talli, sp = 0)

tallm <- rbind(twin_iii, talldf)

twin_plot <- ggplot(tallm, aes(x = prob, y = mp)) +
	theme_classic() +
    geom_errorbar(aes(ymin=mp-sp, ymax=mp+sp), width=.01) +
    geom_line(colour = "black", alpha = 0.25) +
    geom_point() +
    geom_hline(yintercept = 0.05, color="blue", linetype="dashed") +
    scale_x_reverse() +
    xlab("Percent Edges Randomly Kept in Graph") +
    ylab("Twin Paired P-value\n(log10 scale)") +
    scale_y_log10(limits = c(1e-2, 1))



###############
# Final Plots #
###############
finalplot <- plot_grid(
	diet_anosim_plot,
	diet_plot,
	skin_plot,
	twin_plot,
	labels = LETTERS[1:4],
	ncol = 1)

pdf("./figures/interpersonal_div_significance_noise.pdf", width = 6, height = 10)
	finalplot
dev.off()
