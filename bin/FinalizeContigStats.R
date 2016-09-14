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
    metavar = "character"),
  make_option(c("-x", "--circular"),
    type = "character",
    default = NULL,
    help = "Formatted contig circularity table.",
    metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list);
opt <- parse_args(opt_parser);

# Import files
contiglength <- read.delim(opt$lengths, head = FALSE, sep = "\t")
contigcounts <- read.delim(opt$counts, head = TRUE, sep = "\t")
circularlist <- read.delim(opt$circular, head = FALSE, sep = "\t")

head(contiglength)
head(contigcounts)
head(circularlist)

lengthcount <- merge(contiglength, contigcounts, by.x = "V1", by.y = "V1")
colnames(lengthcount) <- c("ContigID", "Length", "Count")

lengthcount$Circularity <- ifelse(lengthcount$ContigID %in% circularlist$V1, "Circular", "Linear")

head(lengthcount[lengthcount$Circularity == "Circular",])

contigstatsplot <- ggplot(lengthcount, aes(x = Length, y = Count, colour = Circularity, alpha=Circularity)) +
    theme_classic() +
    theme(
        axis.line.x = element_line(colour = "black"),
        axis.line.y = element_line(colour = "black"),
        legend.position = c(0.85, 0.9),
        legend.background = element_rect(color = "black", size = 0.5, linetype = "solid"),
        legend.text = element_text(size = 11)) +
    geom_point() +
    scale_colour_manual(values = wes_palette("Royal1")[c(2,1)], name = "Contig Structure") +
    scale_alpha_manual(guide='none', values = c(1.0,0.1)) +
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
  a <- dev.cur()
  png(file="./figures/ContigStats.png",
  height=6,
  width=6,
  units="in",
  res=800)
    dev.control("enable")
        contigstatsplot
    dev.copy(which=a)
  dev.off()
dev.off()
