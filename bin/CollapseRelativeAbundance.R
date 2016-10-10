# CollapseRelativeAbundance.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("Collapsing Contig Relative Abundance Around Clusters", stderr())

library("optparse")
library("plyr")

option_list <- list(
  make_option(c("-i", "--input"),
    type = "character",
    default = NULL,
    help = "Contig count table formatted from bowtie2.",
    metavar = "character"),
  make_option(c("-o", "--out"),
    type = "character",
    default = NULL,
    help = "Output table name",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

input <- read.delim(opt$input, head = FALSE, sep = "\t")

collapsed <- ddply(input, c("V1", "V3"), summarize, sum = sum(V2))

write.table(
  x = collapsed,
  file = opt$out,
  quote = FALSE,
  sep = "\t",
  row.names = FALSE
)

write("Completed Collapsing Relative Abundance Around Clusters", stderr())
