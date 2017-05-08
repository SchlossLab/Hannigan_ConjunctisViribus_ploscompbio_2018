# FinalizeContigStats.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("Performing final contig stats processes.", stderr())

library("optparse")
library("plyr")
library("ggplot2")
library("wesanderson")
library("hexbin")

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

write("Making figure.", stderr())

contigstatsplot <- ggplot(lengthcount, aes(x = Length, y = Count)) +
    theme_classic() +
    scale_x_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))
     ) +
     scale_y_log10(
       breaks = scales::trans_breaks("log10", function(x) 10^x),
       labels = scales::trans_format("log10", scales::math_format(10^.x))) +
     annotation_logticks() +
     stat_binhex(bins = 100) +
     xlab("Length (bp)") +
     ylab("Sequencing Depth")

write("Saving figure.", stderr())

pdf(file = "./figures/ContigStats.pdf",
height = 6,
width = 6)
  contigstatsplot
dev.off()
