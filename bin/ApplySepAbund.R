# ApplySepAbund.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

library("optparse")

option_list <- list(
  make_option(c("-a", "--abundance"),
    type = "character",
    default = NULL,
    help = "Sequence abundance table.",
    metavar = "character"),
  make_option(c("-s", "--samplelist"),
    type = "character",
    default = NULL,
    help = "List of sample IDs to keep.",
    metavar = "character"),
  make_option(c("-c", "--contiglist"),
    type = "character",
    default = NULL,
    help = "List of contig IDs to keep.",
    metavar = "character"),
  make_option(c("-o", "--output"),
    type = "character",
    default = NULL,
    help = "Output table file.",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

input <- read.delim(file=opt$abundance, header=FALSE, sep="\t")
samplelist <- read.delim(file=opt$samplelist, header=FALSE, sep="\t")
contiglist <- read.delim(file=opt$contiglist, header=FALSE, sep="\t")

subsetdf <- input[c(input$V3 %in% samplelist$V1),]
subsetfinal <- subsetdf[c(subsetdf$V1 %in% contiglist$V1),]

write.table(
  x = subsetfinal,
  file = opt$output,
  quote = FALSE,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE
)
