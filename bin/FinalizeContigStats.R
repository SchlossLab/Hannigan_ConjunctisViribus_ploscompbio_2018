# FinalizeContigStats.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("Performing final contig stats processes.", stderr())

library("optparse")
library("plyr")
library("ggplot2")
library("wesanderson")

option_list <- list(
  make_option(c("-l", "--lengths"),
    type = "character",
    default = NULL,
    help = "Formatted contig length information.",
    metavar = "character"),
  make_option(c("-c", "--counts"),
    type = "character",
    default = NULL,
    help = "Formatted contig count table.",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

# Import files
contiglength <- read.delim(opt$lengths, head = FALSE, sep = "\t")
contigcounts <- read.delim(opt$counts, head = TRUE, sep = "\t")

head(contiglength)
head(contigcounts)

lengthcount <- merge(contiglength, contigcounts, by.x = "V1", by.y = "V1")
colnames(lengthcount) <- c("ContigID", "Length", "Count")

contigstatsplot <- ggplot(lengthcount, aes(x = Length, y = Count, wes_palette("Royal1")[c(1)]) +
    theme_classic() +
    theme(
        axis.line.x = element_line(colour = "black"),
        axis.line.y = element_line(colour = "black"),
        legend.position = c(0.85, 0.9),
        legend.background = element_rect(color = "black", size = 0.5, linetype = "solid"),
        legend.text = element_text(size = 11)) +
    geom_point() +
    scale_x_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))
     ) +
     scale_y_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))) +
     annotation_logticks() +
     xlab("Length (bp)") +
     ylab("Sequencing Depth")

pdf(file="./figures/ContigStats.pdf",
height=6,
width=6)
  contigstatsplot
dev.off()
