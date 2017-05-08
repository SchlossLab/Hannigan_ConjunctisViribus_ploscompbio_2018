# sequencedepth.R
# Geoffrey Hannigan
# Schloss Lab
# University of Michigan

gcinfo(TRUE)
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "visNetwork", "scales", "plyr", "cowplot", "vegan", "reshape2", "stringr")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)

graph <- startGraph("http://localhost:7474/db/data/", "neo4j", "root")

### Diet ###

# Get list of the sample IDs
sampleidquery <- "
MATCH
	(x:SRP002424)-->(y)-[d]->(z:Phage)-->(a:Bacterial_Host)<-[e]-(b),
	(b)<--(i:PatientID)-->(y),
	(b)<--(t:TimePoint)-->(y),
	(k:Disease)-->(y)
WHERE toInt(d.Abundance) > 0
OR toInt(e.Abundance) > 0
RETURN DISTINCT
	z.Name AS from,
	a.Name AS to,
	i.Name AS PatientID,
	t.Name AS TimePoint,
	k.Name AS Diet,
	toInt(d.Abundance) AS PhageAbundance,
	toInt(z.Length) AS PhageLength,
	toInt(e.Abundance) AS BacteriaAbundance,
	toInt(a.Length) AS BacteriaLength;
"

sampletable <- as.data.frame(cypher(graph, sampleidquery))

# Correct the lengths
sampletable$PhageAbundance <- round(1e7 * sampletable$PhageAbundance / sampletable$PhageLength)
sampletable$BacteriaAbundance <- round(1e7 * sampletable$BacteriaAbundance / sampletable$BacteriaLength)
sampletable <- sampletable[,-9]
sampletablediet <- sampletable[,-7]
sampletablediet$PatientID <- paste(sampletablediet$PatientID, sampletablediet$TimePoint, sep = "_")
sampletablediet <- sampletablediet[,c("PatientID", "PhageAbundance", "BacteriaAbundance")]
sampletablediet$class <- "Diet"

### Skin ###

# Import graphs into a list
skinsites <- c("Ax", "Ac", "Pa", "Tw", "Um", "Fh", "Ra")
# Start list
graphdfTP2 <- data.frame()
graphdfTP3 <- data.frame()

for (i in skinsites) {
	print(i)
	filename <- paste("./data/skingraph-", i, ".Rdata", sep = "")
	load(file = filename)
	graphdfTP2 <- rbind(graphdfTP2, sampletable)
	rm(sampletable)
}

rm(i)

for (i in skinsites) {
	print(i)
	filename <- paste("./data/skingraph-", i, "-TP3.Rdata", sep = "")
	load(file = filename)
	graphdfTP3 <- rbind(graphdfTP3, sampletable)
	rm(sampletable)
}

rm(i)

totalgraph <- rbind(graphdfTP2, graphdfTP3)

# Correct the lengths
totalgraph$PhageAbundance <- round(1e7 * totalgraph$PhageAbundance / totalgraph$PhageLength)
totalgraph$BacteriaAbundance <- round(1e7 * totalgraph$BacteriaAbundance / totalgraph$BacteriaLength)
totalgraph <- totalgraph[,-9]
sampletableskin <- totalgraph[,-7]
sampletableskin$PatientID <- paste(sampletableskin$PatientID, sampletableskin$TimePoint, sampletableskin$Location, sep = "_")
sampletableskin <- sampletableskin[,c("PatientID", "PhageAbundance", "BacteriaAbundance")]
sampletableskin$class <- "Skin"

### Twins ###

sampleidquery <- "
MATCH
	(x:SRP002523)-->(y)-[d]->(z:Phage)-->(a:Bacterial_Host)<-[e]-(b),
	(b)<--(i:PatientID)-->(y),
	(b)<--(t:TimePoint)-->(y),
	(k:Disease)-->(y)
WHERE toInt(d.Abundance) > 0
OR toInt(e.Abundance) > 0
RETURN DISTINCT
	z.Name AS from,
	a.Name AS to,
	i.Name AS PatientID,
	t.Name AS TimePoint,
	k.Name AS Diet,
	toInt(d.Abundance) AS PhageAbundance,
	toInt(z.Length) AS PhageLength,
	toInt(e.Abundance) AS BacteriaAbundance,
	toInt(a.Length) AS BacteriaLength;
"

sampletable <- as.data.frame(cypher(graph, sampleidquery))
# Correct the lengths
sampletable$PhageAbundance <- round(1e7 * sampletable$PhageAbundance / sampletable$PhageLength)
sampletable$BacteriaAbundance <- round(1e7 * sampletable$BacteriaAbundance / sampletable$BacteriaLength)
sampletable <- sampletable[,-9]
sampletabletwin <- sampletable[,-7]
sampletabletwin$PatientID <- paste(sampletabletwin$PatientID, sampletabletwin$TimePoint, sep = "_")
sampletabletwin <- sampletabletwin[,c("PatientID", "PhageAbundance", "BacteriaAbundance")]
sampletabletwin$class <- "Twin"

### Total ###
sr <- rbind(sampletablediet, sampletableskin, sampletabletwin)
srp <- ddply(sr, c("PatientID", "class"), summarize, value = sum(PhageAbundance))
srb <- ddply(sr, c("PatientID", "class"), summarize, value = sum(BacteriaAbundance))

pp <- ggplot(srp, aes(x = PatientID, y = value, group = class, fill = class)) +
	theme_classic() +
	theme(axis.text.y=element_blank(),
		axis.ticks.y=element_blank()) +
	geom_bar(stat = "identity", width = 1) +
	scale_y_log10() +
	coord_flip() +
	scale_fill_manual(values = wes_palette("Royal1")[c(1,2,4)], name = "Study") +
	xlab("Sample") +
	ylab("Sequences Aligned to Phage OGUs (log10)")

bp <- ggplot(srb, aes(x = PatientID, y = value, group = class, fill = class)) +
	theme_classic() +
	theme(axis.text.y=element_blank(),
		axis.ticks.y=element_blank()) +
	geom_bar(stat = "identity", width = 1) +
	scale_y_log10() +
	coord_flip() +
	scale_fill_manual(values = wes_palette("Royal1")[c(1,2,4)], name = "Study") +
	xlab("Sample") +
	ylab("Sequences Aligned to Bacteria OGUs (log10)")

fp <- plot_grid(pp, bp, nrow = 1, labels = LETTERS[1:2])

pdf(file = "./figures/SequenceAbund.pdf",
height = 6,
width = 10)
  fp
dev.off()
