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
  make_option(c("-m", "--mgrast"),
    type = "character",
    default = NULL,
    help = "MG-RAST input table",
    metavar = "character"),
  make_option(c("-x", "--metadata"),
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
    "SRA_Study_s",
    "Run_s",
    "LibraryLayout_s",
    "Platform_s",
    "Sample_Name_s"
  )]
  return(parsed)
})

mergeddf <- do.call(rbind, listdf)

##########
# MGRAST #
##########
globvector <- Sys.glob(opt$mgrast)
inputfiles <- lapply(globvector, read.delim)

listdf <- lapply(inputfiles, function(x) {
  parsed <- x[, c(
    "ProjectID",
    "MG.RAST.ID",
    "Material",
    "Sequence.Method",
    "Metagenome.Name"
  )]
  colnames(parsed) <- c(
    "SRA_Study_s",
    "Run_s",
    "LibraryLayout_s",
    "Platform_s",
    "Sample_Name_s"
  )
  return(parsed)
})

mgrastdf <- do.call(rbind, listdf)

totaldf <- rbind(mergeddf, mgrastdf)

############################
# Merge with metadata file #
############################
meta <- read.delim(opt$metadata, header = TRUE, sep = "\t")
mergedwithmeta <- merge(
  totaldf, meta,
  by.x = c("SRA_Study_s", "Sample_Name_s"),
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
