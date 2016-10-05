# ReshapeAlignedAbundance.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("PROGRESS: Reshaping contig abundance table.", stderr())

library("optparse")
library("reshape2")

option_list <- list(
  make_option(c("-i", "--input"),
    type = "character",
    default = NULL,
    help = "Contig abundance table.",
    metavar = "character"),
  make_option(c("-o", "--out"),
    type = "character",
    default = NULL,
    help = "Reshaped output table.",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

input <- read.delim(opt$input, head = FALSE, sep = "\t")

collapsed <- dcast(input, V1 ~ V3, value.var="V2")
colnames(collapsed)[1] <- "contig"

collapsed[is.na(collapsed)] <- 0

write.table(
  x = collapsed,
  file = opt$out,
  quote = FALSE,
  sep = "\t",
  row.names = FALSE,
  col.names = TRUE
)

write("PROGRESS: Completed reshaping contig abundance table.", stderr())
