# CluserStats.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("Performing final contig stats processes.", stderr())

library("optparse")
library("plyr")
library("ggplot2")
library("wesanderson")
library("cowplot")

contiglength <- read.delim("./data/PhageContigStats/ContigLength.tsv", head = FALSE, sep = "\t")
bcc <- read.delim(file = "./data/ContigClustersBacteria/clustering_gt1000.csv", head = FALSE, sep = ",")
pcc <- read.delim(file = "./data/ContigClustersPhage/clustering_gt1000.csv", head = FALSE, sep = ",")

mpcc <- merge(pcc, contiglength, by = "V1")
mpcc <- ddply(mpcc, "V2.x", summarize, abund = length(V1), alen = mean(V2.y))
mbcc <- merge(bcc, contiglength, by = "V1")
mbcc <- ddply(mbcc, "V2.x", summarize, abund = length(V1), alen = mean(V2.y))

phageclust <- ggplot(mpcc, aes(x = alen, y = abund)) +
    theme_classic() +
    scale_x_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))
     ) +
     scale_y_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))) +
     annotation_logticks() +
     geom_point() +
     xlab("Average Cluster Length (bp)") +
     ylab("Cluster Contig Count") +
     ggtitle("Phage Operational Genomic Units")

bacclust <- ggplot(mbcc, aes(x = alen, y = abund)) +
    theme_classic() +
    scale_x_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))
     ) +
     scale_y_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))) +
     annotation_logticks() +
     geom_point() +
     xlab("Average Cluster Length (bp)") +
     ylab("Cluster Contig Count") +
     ggtitle("Bacteria Operational Genomic Units")

finalgrid <- plot_grid(phageclust, bacclust, nrow = 1, labels = LETTERS[1:2])

pdf(file = "./figures/ClusterStats.pdf",
height = 6,
width = 10)
  finalgrid
dev.off()
