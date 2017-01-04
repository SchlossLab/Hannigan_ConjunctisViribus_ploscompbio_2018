##################
# Load Libraries #
##################
packagelist <- c("RNeo4j", "ggplot2", "wesanderson", "igraph", "scales", "plyr", "cowplot", "vegan", "reshape2", "parallel")
new.packages <- packagelist[!(packagelist %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos='http://cran.us.r-project.org')
lapply(packagelist, library, character.only = TRUE)

# Some nettools dependencies required bioconductor installations
# Follow the on-screen instructions

###################
# Set Subroutines #
###################
effinrarefaction <- function (x, sample) 
{
    if (!identical(all.equal(x, round(x)), TRUE)) 
        stop("function is meaningful only for integers (counts)")
    x <- as.matrix(x)
    if (ncol(x) == 1) 
        x <- t(x)
    if (length(sample) > 1 && length(sample) != nrow(x)) 
        stop(gettextf("length of 'sample' and number of rows of 'x' do not match"))
    sample <- rep(sample, length = nrow(x))
    colnames(x) <- colnames(x, do.NULL = FALSE)
    nm <- colnames(x)
    if (any(rowSums(x) < sample)) 
        warning("Some row sums < 'sample' and are not rarefied")
    for (i in 1:nrow(x)) {
        if (sum(as.numeric(x[i, ])) <= sample[i]) 
            next
        row <- sample(rep(nm, times = x[i, ]), sample[i])
        row <- table(row)
        ind <- names(row)
        x[i, ] <- 0
        x[i, ind] <- row
    }
    x
}

##############################
# Run Analysis & Save Output #
##############################
# Import graphs into a list
skinsites <- c("Ax", "Ac", "Pa", "Tw", "Um", "Fh", "Ra")
# Start list
graphdf <- data.frame()

for (i in skinsites) {
	print(i)
	filename <- paste("./data/skingraph-", i, ".Rdata", sep = "")
	load(file = filename)
	graphdf <- rbind(graphdf, sampletable)
}

# Run subsampling

phageminseq <- min(ddply(graphdf, c("PatientID", "Diet"), summarize, sum = sum(as.numeric(PhageAbundance)))$sum)
bacminseq <- min(ddply(graphdf, c("PatientID", "Diet"), summarize, sum = sum(as.numeric(BacteriaAbundance)))$sum)

# Rarefy each sample using sequence counts
rout <- lapply(unique(graphdf$PatientID), function(i) {
	subsetdfout <- as.data.frame(graphdf[c(graphdf$PatientID %in% i),])
	outputin <- lapply(unique(subsetdfout$Diet), function(j) {
		print(c(i, j))
		subsetdfin <- subsetdfout[c(subsetdfout$Diet %in% j),]
		subsetdfin$PhageAbundance <- c(effinrarefaction(subsetdfin$PhageAbundance, sample = phageminseq))
		subsetdfin$BacteriaAbundance <- c(effinrarefaction(subsetdfin$BacteriaAbundance, sample = bacminseq))
		return(subsetdfin)
	})
	forresult <- as.data.frame(do.call(rbind, outputin))
	return(forresult)
})

save(rout, file = "./data/rout.Rdata")

# Finish making subsampled data frame
rdf <- as.data.frame(do.call(rbind, rout))
# Remove those without bacteria or phage nodes after subsampling
# Zero here means loss of the node
rdf <- rdf[!c(rdf$PhageAbundance == 0 | rdf$BacteriaAbundance == 0),]
# Calculate edge values from nodes
rdf$edge <- log10(rdf$PhageAbundance * rdf$BacteriaAbundance)

