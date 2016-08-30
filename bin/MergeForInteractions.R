# MergeForInteractions.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("Formatting Interaction Data", stderr())

library("optparse")

option_list <- list(
  make_option(c("-b", "--bacteria"),
    type = "character",
    default = NULL,
    help = "Bacteria ID Table.",
    metavar = "character"),
  make_option(c("-i", "--interaction"),
    type = "character",
    default = NULL,
    help = "Phage - Bacteria Interaction Table",
    metavar = "character"),
  make_option(c("-o", "--out"),
    type = "character",
    default = NULL,
    help = "Output Table Name",
    metavar = "character")
)

opt_parser <- OptionParser(option_list=option_list);
opt <- parse_args(opt_parser);

bacteria <- read.delim(opt$bacteria, head=TRUE, sep="\t")
interactions <- read.delim(opt$interaction, head=FALSE, sep="\t")

mergeddf <- merge(bacteria, interactions, by.x="PhageHit", by.y="V2")

mergedsubset <- mergeddf[,c("SpecificBacterialID", "V1", "V3")]

mergedsubset <- mergedsubset[complete.cases(mergedsubset),]

write.table(
  x = mergedsubset,
  file = opt$out,
  quote = FALSE,
  sep = "\t",
  row.names = FALSE
)

write("Completed Formatting Interaction Data", stderr())
