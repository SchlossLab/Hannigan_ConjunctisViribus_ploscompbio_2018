#! /usr/local/bin/R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

write("Parsing sequencing metadata...", stderr())

library("optparse")

option_list <- list(
  make_option(c("-i", "--input"),
    type = "character",
    default = NULL,
    help = "Input table with word count information.",
    metavar = "character"),
  make_option(c("-m", "--metadata"),
    type = "character",
    default = NULL,
    help = "Metadata input table",
    metavar = "character"),
  make_option(c("-o", "--out"),
    type = "character",
    default = NULL,
    help = "PNG output file for summary plot",
    metavar = "character")
)

opt_parser <- OptionParser(option_list=option_list);
opt <- parse_args(opt_parser);

#######
# SRA #
#######
globvector <- Sys.glob(opt$input)

# Import the file
inputfiles <- lapply(globvector, read.delim)

# Parse the files
listdf <- lapply(inputfiles, function(x) {
  parsed <- x[, c(
    "SRAStudy",
    "Run",
    "LibraryLayout",
    "Platform",
    "SampleName"
  )]
  return(parsed)
})

mergeddf <- do.call(rbind, listdf)

############################
# Merge with metadata file #
############################
meta <- read.delim(opt$metadata, header = TRUE, sep = "\t")

head(meta)

mergedwithmeta <- merge(
  mergeddf, meta,
  by.x = c("SRAStudy", "SampleName"),
  by.y = c("StudyID", "SampleName")
)

write.table(
  x = mergedwithmeta,
  file = opt$out,
  quote = FALSE,
  sep = "\t",
  row.names = FALSE
)

write("Completed parsing sequencing metadata...", stderr())
