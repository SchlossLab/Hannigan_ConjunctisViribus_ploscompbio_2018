# Set libraries
library(reshape2)
library(ggplot2)
library(RColorBrewer)
library(vegan)
library(cowplot)

RelAbundTable <- read.delim("../data/OPFs/OpfAbundanceTable.tsv", 
	sep="\t", 
	header=FALSE)

RelAbundTable <- RelAbundTable[,-1]
RelAbundTable <- RelAbundTable[-1,]
TelAbundTable <- data.frame(t(RelAbundTable))

SelAbundTable <- sapply(TelAbundTable, function(x) x %in% 0)

TelAbundTableBoolean <- data.frame(t(SelAbundTable))

Sums <- rowSums(TelAbundTableBoolean[,1:2])

# Get the frequency of zero values over repeated permutations
permuteddf <- do.call("rbind", lapply(c(1:10), function(y)
	{
	# Set the random permutation
	ShuffledTelAbund <- TelAbundTableBoolean[,sample(ncol(TelAbundTableBoolean))]
	dfsum <- data.frame(sapply(c(2:length(ShuffledTelAbund)), function(x) sum(c(rowSums(ShuffledTelAbund[,1:x]) == 0), na.rm=TRUE)))
	colnames(dfsum) <- "CoreOpfs"
	dfsum$permutation <- c(y)
	dfsum$Samples <- as.numeric(row.names(dfsum)) + 1
	dfsum
	}
))

coreOpfPermute <- ggplot(permuteddf, aes(x=Samples, y=CoreOpfs, group=factor(permutation), colour=factor(permutation))) +
	theme_classic() +
	theme(axis.line.x = element_line(color="black"),
		axis.line.y = element_line(color="black")) +
	geom_line() +
	scale_colour_brewer(palette="Paired") +
	ggtitle("Core OPFs Across Increasing Human Virome Samples")
coreOpfPermute

pdf("../figures/CoreOpfPermutations.pdf", height=6, width=4)
	coreOpfPermute
dev.off()

png("../figures/CoreOpfPermutations.png", height=6, width=4, units = "in", res=800)
	coreOpfPermute
dev.off()

