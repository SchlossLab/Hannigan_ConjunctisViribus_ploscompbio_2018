# PlotBenchmarkInteractions.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################

setwd("~/git/Hannigan-2016-ConjunctisViribus")
library("ggplot2")
library("reshape2")

################
# Run Analysis #
################

# Import data frame
input <- read.delim(file="./data/ValidationSet/Interactions.tsv",
  sep="\t",
  header=FALSE)

heatmap <- ggplot(input, aes(V1, V2)) +
  theme_classic() +
  geom_tile(aes(fill=factor(V3))) +
  scale_fill_brewer(palette="Set1",
    guide = guide_legend(title = "Interactions")) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  ylab("Bacteria") +
  xlab("Bacteriophages") +
  ggtitle("Bacteriophage - Bacteria Benchmark Interactions")

###############
# Save Output #
###############

width <- 10
height <- 10

pdf(file="./figures/BenchmarkDataset.pdf",
width=width,
height=height)
  a <- dev.cur()
  png(file="./figures/BenchmarkDataset.png",
  width=width,
  height=height,
  units="in",
  res=800)
    dev.control("enable")
    # ggplot heatmap
    heatmap
    dev.copy(which=a)
  dev.off()
dev.off()
