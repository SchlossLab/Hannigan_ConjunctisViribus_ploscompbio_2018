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

# Read in the data files
crisprs <- read.delim(
	file = "./data/SecondaryBenchmarkingSet/BenchmarkCrisprsFormat.tsv",
	header = FALSE,
	sep = "\t")

prophages <- read.delim(
	file = "./data/SecondaryBenchmarkingSet/BenchmarkProphagesFormatFlip.tsv",
	header = FALSE,
	sep = "\t")

# To match original build, need low bitscore here as features
prophages <- prophages %>%
	group_by(V1, V2) %>%
	summarize(V3 = min(V3)) %>%
	as.data.frame()

blastxresults <- read.delim(
	file = "./data/SecondaryBenchmarkingSet/MatchesByBlastxFormatOrder.tsv",
	header = TRUE,
	sep = "\t")

colnames(blastxresults) <- c("V1", "V2", "V3")

pfaminteractions <- read.delim(
	file = "./data/SecondaryBenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv",
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

totalcounts <- knownjoins %>%
	group_by(V1) %>%
	summarize(total = length(V2)) %>%
	as.data.frame()

# Join the counts
mergecounts <- left_join(resultsj, totalcounts, by = c("V1" = "V1"))
mergecounts$missed <- mergecounts$total - mergecounts$hit
mergecounts <- mergecounts[,-3]
mg <- gather(mergecounts, V1)
colnames(mg) <- c("name", "hit", "value")
mg <- arrange(mg, desc(value))
mg$name <- factor(mg$name, levels = mg$name)

outplot <- ggplot(mg, aes(x = name, y = value, fill = hit)) +
	theme_classic() +
	geom_bar(stat = "identity", width = 1) +
	coord_flip() +
	scale_fill_viridis(discrete=TRUE) +
	xlab("Phage Name") +
	ylab("Number of Matched Bacteria")

pdf(
	file = "./figures/SecondaryValidation.pdf",
	height = 40,
	width = 18
)
	outplot
dev.off()



