#! /usr/local/bin/R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

packagelist <- c("RNeo4j", "ggplot2", "optparse", "caret", "wesanderson", "plotROC")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(packagelist, library, character.only = TRUE)
library("dplyr")
library("tidyr")
library("viridis")

# Load in the random forest model
load("./data/rfinteractionmodel.RData")

hitlout <- lapply(c(1, 0.9, 0.8, 0.7, 0.6, 0.5), function(i) {
	# Read in the data files
	crisprs <- read.delim(
		file = paste("./data/SecondaryBenchmarkingSet_", i, "/BenchmarkCrisprsFormat_", i, ".tsv", sep = ""),
		header = FALSE,
		sep = "\t")
	
	prophages <- read.delim(
		file = paste("./data/SecondaryBenchmarkingSet_", i, "/BenchmarkProphagesFormatFlip_", i, ".tsv", sep = ""),
		header = FALSE,
		sep = "\t")
	
	# To match original build, need low bitscore here as features
	prophages <- prophages %>%
		group_by(V1, V2) %>%
		summarize(V3 = min(V3)) %>%
		as.data.frame()
	
	blastxresults <- read.delim(
		file = paste("./data/SecondaryBenchmarkingSet_", i, "/MatchesByBlastxFormatOrder_", i, ".tsv", sep = ""),
		header = TRUE,
		sep = "\t")
	
	colnames(blastxresults) <- c("V1", "V2", "V3")
	
	pfaminteractions <- read.delim(
		file = paste("./data/SecondaryBenchmarkingSet_", i, "/PfamInteractionsFormatScoredFlip_", i, ".tsv", sep = ""),
		header = TRUE,
		sep = "\t")
	
	colnames(pfaminteractions) <- c("V1", "V2", "V3")
	
	# Start joining together the data frames
	j1 <- full_join(crisprs, prophages, by = c("V1" = "V1", "V2" = "V2"))
	j2 <- full_join(j1, blastxresults, by = c("V1" = "V1", "V2" = "V2"))
	j3 <- full_join(j2, pfaminteractions, by = c("V1" = "V1", "V2" = "V2"))
	
	j3[,3:6] <- as.data.frame(sapply(j3[,3:6], as.numeric))
	rownames(j3) <- NULL
	j3[is.na(j3)] <- 0
	
	fdf <- data.frame(j3[apply(j3[, -c(1:2)], MARGIN = 1, function(x) any(x > 0)),])
	
	colnames(fdf) <- c("Bacteria", "Phage", "CRISPR", "Blast", "Blastx", "Pfam")
	
	predout <- predict(outmodel, newdata=fdf)
	
	predresulttable <- cbind(fdf[,c(1:2)], predout)
	colnames(predresulttable) <- c("Bacteria", "Phage", "InteractionScore")
	
	# Load in the reference with the known interactions (species level)
	sintr <- read.delim(
		file = "./data/genbankPhageHost/viral_host_species_nospace.tsv",
		sep = "\t",
		header = FALSE)
	
	# Convert the interaction data frame to only species level bacteria
	predresulttable$Bacteria <- gsub("^([A-Za-z]+_[A-Za-z]+)_.*", "\\1", predresulttable$Bacteria, perl = TRUE)
	
	# Join the expected and predicted interaction tables
	knownjoins <- left_join(sintr, predresulttable, by = c("V1" = "Phage", "V2" = "Bacteria"))
	
	# Quantify the number of interactions that were detected
	resultsj <- knownjoins %>%
		filter(InteractionScore %in% "Interacts") %>%
		group_by(V1) %>%
		summarize(hit = length(V2)) %>%
		as.data.frame()
	
	hitcount <- nrow(resultsj)

	return(data.frame(fraction = i, hits = hitcount))
})

outhits <- do.call(rbind, hitlout)

iterplot <- ggplot(outhits, aes(x = fraction, y = hits)) +
	theme_classic() +
	geom_line() +
	scale_x_reverse() +
	scale_y_continuous(limit = c(0, 250)) +
	xlab("Fraction of Genome Used For Contig") +
	ylab("Number of Identified Interactions")

pdf(
	file = "./figures/SecondaryValidationIterationContigs.pdf",
	height = 6,
	width = 8
)
	iterplot
dev.off()


