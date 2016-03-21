---
file: OutlineAndIdeas.md
date: 2016-01-27
---

#Manuscript
##Results

1. **Network Contruction & Validation**

This section will launch into the results by describing how I constructed the interactive network. This will include a **figure** of the visualized network (igraph) to give the reader an idea of how it looks from 10,000 feet. The explanation will include reasons for why I chose the parameters that I did, and how I assigned confidence scores in those parameters.

I will also include the validation experiments to establish why this model and the associated parameters should even be trusted. This will include how accurately I can predict interactions between phages using known literature information, which is already included in the model anyways.

2. Examining the Most Highly Connected Bacteria/Phages

This will include an analysis of which phages display wide vs narrow host ranges, and which are the best connected.

Most highly connected will be defined by the nodes with the greatest number of edges.

3. Defining the Core Interactive Phages and the Isolated Outliers

This will follow directly from the previous section.

4. Network Shifts in Disease States

Nobody is going to care about this unless it has some medical utility. Right now I am thinking about mapping reads from a couple studies to the reference genomes in my database and evaluate the best represented nodes and their edges. I could see each disease dataset represented as a different text section.

This is still very much a work in progress so I am going to have to think more about this.



#Outline Ideas

1. Database Construction
2. Benchmarking and Confidence
3. Gut Virome Host Ranges and Clusters
4. Associations with IBD (Virgin Dataset)
5. Associations with Antibiotics (Modi Dataset)
6. Predicting host preferences, future evolution, and future interactions (social network approach)
7. Functionally Attempt Spiking Mouse Microbiome with Predicted Impactful Phgaes (ATCC Focus)

##Predictive Models
There are different ways graph databases can be used for predictive modeling and classificaiton.

1. Use database features as features within the predictive model (e.g. edges on the node, shortest paths)
2. Use triadic closures to classify phages related by shared hosts to predict genetic exchange, competition, & co-dependence
3. Classification algorithms by edge clustering
4. Is it possible to create binary arrays of phage-bacteria infectious ranges and classify system as diseased based on interactions?


IMPORTANT POINT: Add section for how incorrect the host ranges are
