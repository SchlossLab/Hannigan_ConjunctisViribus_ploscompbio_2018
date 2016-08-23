library("optparse")

option_list <- list(
  make_option(c("-i", "--input"),
    type = "character",
    default = NULL,
    help = "Input table with word count information.",
    metavar = "character"))

opt_parser <- OptionParser(option_list=option_list);
opt <- parse_args(opt_parser);

Sys.glob(opt$input)
