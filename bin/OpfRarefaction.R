# Set libraries
library(reshape2)
library(ggplot2)
library(RColorBrewer)
library(vegan)
library(cowplot)

RelAbundTable <- read.delim("../data/OPFs/TotalSeqs.fa-bowtie.tsv", sep="\t", header=TRUE, row.names=1)
RelAbundTableInt <- data.frame(sapply(RelAbundTable, function(x) as.integer(ceiling(x))))

RelAbundTrans <- data.frame(t(RelAbundTableInt))
raremax <- min(rowSums(RelAbundTrans))
step <- round(raremax / 1000)

rarecurve <- c(rarecurve(RelAbundTrans, step=step, sample = raremax, label=FALSE, col = "blue", xlim=c(0, raremax)))
datrare <- data.frame(rarecurve)
datrare$V1 <- as.numeric(gsub("N", "", rownames(datrare)))
colnames(datrare) <- c("Richness", "SequenceCount")

rarefactionplot <- ggplot(datrare, aes(x=SequenceCount, y=Richness)) +
	theme_classic() +
	theme(axis.line.x = element_line(color="black"),
		axis.line.y = element_line(color="black")) +
	geom_line()
rarefactionplot

historgramplot <- ggplot(RelAbundTable, aes(x=count)) +
	theme_classic() +
	theme(axis.line.x = element_line(color="black"),
		axis.line.y = element_line(color="black")) +
	geom_density(fill="grey", alpha=0.5) +
	xlab("OPF Sequence Hits (log)") +
	scale_x_log10()

multiplot <- plot_grid(rarefactionplot, historgramplot, labels = c('A', 'B'), ncol=1)

pdf("../figures/OpfRarefaction.pdf", height=6, width=4)
	multiplot
dev.off()

png("../figures/OpfRarefaction.png", height=6, width=4, units = "in", res=800)
	multiplot
dev.off()