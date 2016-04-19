#/usr/local/bin/R
# PlotClusterBenchmark.R
# Geoffrey Hannigan
# Pat Schloss Lab

#################
# Set Libraries #
#################

library("ggplot2")
library("optparse")

#################################
# Parse Input from Command Line #
#################################

option_list <- list(
  make_option(c("-i", "--input"),
    type="character",
    default=NULL,
    help="Input table with word count information.",
    metavar="character"),
  make_option(c("-o", "--out"),
    type="character",
    default=NULL,
    help="PNG output file for summary plot",
    metavar="character")
);

opt_parser <- OptionParser(option_list=option_list);
opt <- parse_args(opt_parser);

################
# Run Analysis #
################

# Import the file
input <- read.delim(file=opt$input, sep="\t", header=FALSE)

# Plot the results
statsplot <- ggplot(input, aes(x=V1, y=V2)) +
  theme_classic() +
  geom_line() +
  geom_point() +
  xlab("Percent Similarity Threshold") +
  ylab("Unique Sequence Count")

png(file=opt$out, width=8, height=6, units="in", res=300)
  statsplot
dev.off()
