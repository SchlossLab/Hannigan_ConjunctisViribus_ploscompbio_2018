##################
# Load Libraries #
##################
gcinfo(TRUE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "vegan", "reshape2", "stringr")
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

linediet <- ggplot(ravg, aes(x = class, y = avg, group = patient1)) +
	theme_classic() +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black")
	) +
	geom_line(colour = wes_palette("Royal1")[2]) +
	geom_point(colour = "black") +
	ylab("EV Centrality Distance") +
	xlab("")

densitydiet <- ggplot(ravgslope, aes(y)) +
	theme_classic() +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black")
	) +
	geom_density() +
	geom_vline(xintercept = 0, linetype = "dashed") +
	ylab("Probability") +
	xlab("Intrapersonal Change") +
	xlim(range(pdf$x))

intrabetadiv <- plot_grid(linediet, densitydiet, rel_heights = c(4, 1), ncol = 1)

## Ordination ###
ORD_NMDS <- metaMDS(comm = rdist, k=2)
ORD_FIT = data.frame(MDS1 = ORD_NMDS$points[,1], MDS2 = ORD_NMDS$points[,2])
ORD_FIT$SampleID <- rownames(ORD_FIT)
# Get metadata
ORD_FIT <- cbind(ORD_FIT, as.data.frame(str_split_fixed(ORD_FIT$SampleID, "_", 2)))

plotnmds_dietstudy <- ggplot(ORD_FIT, aes(x=MDS1, y=MDS2, colour=factor(V1))) +
    theme_classic()  +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black"),
	  legend.position = "bottom"
	) +
    geom_point() +
    scale_colour_manual(values = wes_palette("Royal2"), name = "Subject")

anosim(rdist, ORD_FIT$V1)

##############
# Skin Graph #
##############
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
rm <- cbind(rdm, as.data.frame(str_split_fixed(rdm$Var1, "_", 3)))
rm <- cbind(rm, as.data.frame(str_split_fixed(rm$Var2, "_", 3)))
rm <- rm[,-c(1:2)]
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

skinline <- ggplot(ravg, aes(x = class, y = avg, group = merged)) +
	theme_classic() +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black")
	) +
	geom_line(colour = wes_palette("Royal1")[2]) +
	geom_point(colour = "black") +
	ylab("EV Centrality Distance") +
	xlab("")

skinden <- ggplot(ravgslope, aes(y)) +
	theme_classic() +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black")
	) +
	geom_density() +
	geom_vline(xintercept = 0, linetype = "dashed") +
	ylab("Probability") +
	xlab("Intrapersonal Change") +
	xlim(range(pdf$x))

intrabetadiv_personal <- plot_grid(skinline, skinden, rel_heights = c(4, 1), ncol = 1)

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

twinline <- ggplot(ravg, aes(x = class, y = avg, group = patient1)) +
	theme_classic() +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black")
	) +
	geom_line(colour = wes_palette("Royal1")[2]) +
	geom_point(colour = "black") +
	ylab("EV Centrality Distance") +
	xlab("")

twinden <- ggplot(ravgslope, aes(y)) +
	theme_classic() +
	theme(
	  axis.line.x = element_line(colour = "black"),
	  axis.line.y = element_line(colour = "black")
	) +
	geom_density() +
	geom_vline(xintercept = 0, linetype = "dashed") +
	ylab("Probability") +
	xlab("Intrapersonal Change") +
	xlim(range(pdf$x))

intrabetadivwithmothers <- plot_grid(twinline, twinden, rel_heights = c(4, 1), ncol = 1)

###############
# Final Plots #
###############
boxplots <- plot_grid(
	intrabetadiv,
	intrabetadiv_personal,
	intrabetadivwithmothers,
	labels = c("B", "C", "D"), ncol = 3)

finalplot <- plot_grid(plotnmds_dietstudy, boxplots, labels = c("A"), rel_widths = c(1, 2))

pdf("./figures/intrapersonal_diversity.pdf", width = 12, height = 5)
	finalplot
dev.off()
