# PlotBenchmarkInteractions.R
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

##################
# Load Libraries #
##################
library("ggplot2")
library("reshape2")
library("wesanderson")
library("plyr")
library("cowplot")
library("ggmap")
library(maptools)
library(maps)

################
# Run Analysis #
################

# Import data frame
input <- read.delim(file="./data/ValidationSet/Interactions.tsv",
  sep="\t",
  header=TRUE)
genometypes <- read.delim(file="./data/ValidationSet/PhageGenomeTypes.tsv",
  sep="\t",
  header=FALSE)
genometypes$V1 <- gsub("_", " ", genometypes$V1, perl=TRUE)
samplemetadata <- read.delim(file="./data/PublishedDatasets/metadatatable.tsv",
  sep="\t",
  header=TRUE)

input$SpecificBacterialID <- gsub("([^_]+_[^_]+)_.*", "\\1", input$SpecificBacterialID, perl=TRUE)
input$V3 <- gsub(0, "Negative", input$V3, perl=TRUE)
input$V3 <- gsub(1, "Positive", input$V3, perl=TRUE)
input$SpecificBacterialID <- gsub("_", " ", input$SpecificBacterialID, perl=TRUE)
input$V1 <- gsub("_", " ", input$V1, perl=TRUE)

heatmap <- ggplot(input, aes(V1, SpecificBacterialID)) +
  theme_bw() +
  theme(
    axis.line.x = element_line(colour = 'black', size=0.5, linetype='solid'),
    axis.line.y = element_line(colour = 'black', size=0.5, linetype='solid'),
    legend.position="right") +
  geom_tile(aes(fill=factor(V3))) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  ylab("") +
  xlab("") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_manual(values = wes_palette("Royal1")[c(2,1)], name = "Interactions")

hostcount <- ddply(input[!c(input$V3 %in% "Negative"),], c("V1"), summarize, count=length(SpecificBacterialID))
hostcount <- hostcount[order(hostcount$count, decreasing=FALSE),]
hostcount$V1 <- factor(hostcount$V1, levels=hostcount$V1)

countbar <- ggplot(hostcount, aes(x=V1, y=count, fill="fill")) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = 'black', size=0.5, linetype='solid'),
    axis.line.y = element_line(colour = 'black', size=0.5, linetype='solid'),
    legend.position="none") +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = wes_palette("Royal1")[c(2)]) +
  coord_flip() +
  xlab("") +
  ylab("Host Strains")

genomecount <- ddply(genometypes, c("V3"), summarize, genomeshape = length(V3))
colnames(genomecount) <- c("V2", "linear")
shapecount <- ddply(genometypes, c("V2"), summarize, genomeshape = length(V2))

stackedbar <- function(x) {
  ggplot(melt(x), aes(x=variable, y=value, fill=V2)) +
  theme_classic() +
  theme(
    axis.line.x = element_line(colour = 'black', size=0.5, linetype='solid'),
    legend.position="right",
    axis.ticks.y=element_blank(),
    axis.title.y=element_blank(),
    axis.text.y=element_blank()) +
  geom_bar(stat = "identity", position="fill") +
  xlab("") +
  ylab("Relative Percent") +
  scale_fill_manual(values = wes_palette("Royal1")[c(2,1,4)], name = "") +
  coord_flip()
}

circulartype <- stackedbar(genomecount)
dnatype <- stackedbar(shapecount)

# Make vector of locations for coordinates
locationsites <- unique(samplemetadata$Location)
locationsites <- as.character(locationsites[!is.na(locationsites)])
# Get locations
sitegeocodes <- geocode(locationsites)

#Using GGPLOT, plot the Base World Map
mp <- NULL
mapWorld <- borders("world", colour=wes_palette("Royal1")[1], fill=wes_palette("Royal1")[1]) # create a layer of borders
mapplot <-  ggplot(sitegeocodes, aes(x=lon, y=lat)) +
  theme_classic() +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank(),
        axis.title.y=element_blank(),
        axis.text.y=element_blank(),
        axis.ticks.y=element_blank()) +
  mapWorld +
  geom_point(color=wes_palette("Royal1")[2], size=3)


barside <- plot_grid(dnatype, circulartype, labels = c("D", "E"), ncol = 1)
buildingalmost <- plot_grid(mapplot, countbar, barside, labels = c("B", "C"), ncol = 1, rel_heights=c(2,2,1))
donebuild <- plot_grid(heatmap, buildingalmost, labels = c("A"), ncol = 2)
donebuild

###############
# Save Output #
###############

width <- 16
height <- 10

pdf(file="./figures/BenchmarkDataset.pdf",
width=width,
height=height)
  a <- dev.cur()
  png(file="./figures/BenchmarkDataset.png",
  width=width,
  height=height,
  units="in",
  res=800)
    dev.control("enable")
    # ggplot heatmap
    donebuild
    dev.copy(which=a)
  dev.off()
dev.off()
