---
title: Biogeography and Environmental Conditions Shape Phage and Bacteria Interaction Networks Across the Healthy Human Microbiome
author:
- name: Geoffrey D Hannigan
  affiliation: 1
- name: Melissa B Duhaime
  affiliation: 2
- name: Danai Koutra
  affiliation: 3
- name: Patrick D Schloss
  affiliation: 1,\*
address:
  - code: 1
    address: Department of Microbiology & Immunology, University of Michigan, Ann Arbor, Michigan, 48109
  - code: 2
    address: Department of Ecology and Evolutionary Biology, University of Michigan, Ann Arbor, Michigan, 48109
  - code: 3
    address: Department of Computer Science, University of Michigan, Ann Arbor, Michigan, 48109
  - code: \*
    address: To whom correspondence may be addressed.
output:
  md_document:
    variant: markdown
fontsize: 11pt
mainfont: 'Helvetica'
---

&nbsp;

| ***Corresponding Author Information***
| Patrick D Schloss, PhD
| 1150 W Medical Center Dr. 1526 MSRB I
| Ann Arbor, Michigan 48109
| Phone: (734) 647-5801
| Email: pschloss@umich.edu

***Running Title***: Network Diversity of the Healthy Human Microbiome

***Journal***: mSystems

***Keywords***: Virome, Microbiome, Graph Theory, Machine Learning

***Abstract Length***: 236 / 250

***Importance Length***: 145 / 150

***Text Length***: 4,987 / 5,000 Words

\* *Figures at the end of the document for internal review only.*

\newpage



# Abstract
Viruses and bacteria are critical components of the human microbiome and play important roles in health and disease. Most previous work has relied on studying microbes and viruses independently, thereby reducing them to two separate communities. Such approaches are unable to capture how these microbial communities interact, such as through processes that maintain community stability or allow phage-host populations to co-evolve. We developed and implemented a network-based analytical approach to describe phage-bacteria network diversity throughout the human body. We accomplished this by building a machine learning algorithm to predict which phages could infect which bacteria in a given microbiome. This algorithm was applied to paired viral and bacterial metagenomic sequence sets from three previously published human cohorts. We organized the predicted interactions into networks that allowed us to evaluate phage-bacteria connectedness across the human body. We found that gut and skin network structures were person-specific and not conserved among cohabitating family members. High-fat diets and obesity were associated with less connected networks. Network structure differed between skin sites, with those exposed to the external environment being less connected and more prone to instability. This study quantified and contrasted the diversity of virome-microbiome networks across the human body and illustrated how environmental factors may influence phage-bacteria interactive dynamics. This work provides a baseline for future studies to better understand system perturbations, such as disease states, through ecological networks.

# Importance

The human microbiome, the collection of microbial communities that colonize the human body, is a crucial component to health and disease. Two major components to the human microbiome are the bacterial and viral communities. These communities have primarily been studied separately using metrics of community composition and diversity. These approaches have failed to capture the complex dynamics of interacting bacteria and phage communities, which frequently share genetic information and work together to maintain stable ecosystems. Removal of bacteria or phage can disrupt or even collapse those ecosystems. Relationship-based network approaches allow us to capture this interaction information. Using this network-based approach with three independent human cohorts, we were able to present an initial understanding of how phage-bacteria networks differ throughout the human body, so as to provide a baseline for future studies of how and why microbiome networks differ in disease states.

\newpage

# Introduction

Viruses and bacteria are critical components of the human microbiome and play important roles in health and disease. Bacterial communities have been associated with disease states, including a range of skin conditions [@Hannigan:2013im], acute and chronic wound healing conditions [@Hannigan:2014be; @Loesche:2016ev], and gastrointestinal diseases, such as inflammatory bowel disease [@He:2016ch; @Norman:2015kb], *Clostridium difficile* infections [@Seekatz:2016fz] and colorectal cancer [@Zackular:2014fba; @Baxter:2014hb]. Altered human viromes (virus communities consisting primarily of bacteriophages) also have been  associated with diseases and perturbations, including inflammatory bowel disease [@Norman:2015kb; @Manrique:2016dx], periodontal disease [@Ly:2014ew], spread of antibiotic resistance [@Modi:2013fia], and others [@Monaco:2016ita; @Hannigan:2015fz; @Minot:2011ez; @SantiagoRodriguez:2015gd; @Abeles:2015dy; @Abeles:2014kj]. Viruses act in concert with their microbial hosts as a single ecological community [@Haerter:2014ii]. Viruses influence their living microbial host communities through processes including lysis, host gene expression modulation [@Lindell:2005gz, @Tyler:2013fl, @Hargreaves:2014ja], influence on evolutionary processes such as horizontal gene transfer [@Moon:2015fa, @Modi:2013fi, @Ogg:1981th, @Frost:2005dn] or antagonistic co-evolution [@Koskella:2014ds], and alteration of ecosystem processes and elemental stoichiometry [@Jover:2014gq].

Previous human microbiome work has focused on bacterial and viral communities, but have reduced them to two separate communities by studying them independently  [@Norman:2015kb; @Manrique:2016dx; @Ly:2014ew; @Monaco:2016ita; @Hannigan:2015fz; @Minot:2011ez; @SantiagoRodriguez:2015gd; @Abeles:2015dy; @Abeles:2014kj]. This approach fails to capture the complex dynamics of interacting bacteria and phage communities, which frequently share genetic information and work together to maintain stable ecosystems. Removal of bacteria or phage can disrupt or even collapse those ecosystems [@Haerter:2014ii; @Harcombe:2005fd; @Middelboe:2001fl; @Poisot:2011jc; @Thompson:2012ki; @Moebus:1981kp; @Flores:2013hc; @Poisot:2012fh; @Poisot071993; @Flores:2011bh; @Jover:2015ev]. Relationship-based network approaches allow us to capture this interaction information. Studying such bacteria-phage interactions through community-wide networks built from inferred relationships could offer further insights into the drivers of human microbiome diversity across body sites and enable the study of human microbiome network dynamics overall.

In this study, we characterized human-associated bacterial and phage communities by their inferred relationships using three published paired virus and bacteria-dominated whole community metagenomic datasets [@Hannigan:2015fz; @Minot:2011ez; @Reyes:2010cwa; @Turnbaugh:2009ei].  We leveraged machine learning and graph theory techniques to establish and explore the human bacteria-phage network diversity therein. This approach built upon previous large-scale phage-bacteria network analyses by inferring interactions from metagenomic datasets, rather than culture-dependent data [@Flores:2013hc], which is limited in the scale of possible experiments and analyses. Our metagenomic interaction inference model improved upon previous models of phage-host predictions that have utilized a variety of techniques, such as linear models to predict bacteria-phage co-occurrence using taxonomic assignments [@LimaMendez:2015hw], and nucleotide similarity models that were applied to both whole virus genomes [@Edwards:2015iz] and related clusters of whole and partial virus genomes [@@Roux:2016cc]. Our approach uniquely included protein interaction data and was validated based on experimentally determined positive and negative interactions (i.e. who does and does not infect whom). Through this approach we were able to provide a basic understanding of the network dynamics associated with phage and bacterial communities on and in the human body. By building and utilizing a microbiome network, we found that different people, body sites, and anatomical locations not only support distinct microbiome membership and diversity [@Hannigan:2015fz; @Minot:2011ez; @Reyes:2010cwa; @Turnbaugh:2009ei; @Grice:2009eea; @Findley:2013jf; @Costello:2009im, @Consortium:2012iz], but also support ecological communities with distinct communication structures and propensities toward community instability. Through an improved understanding of network structures across the human body, we empower future studies to investigate how these communities dynamics are influenced by disease states and the overall impact they may have on human health.


# Results

## Cohort Curation and Sample Processing
We studied the differences in virus-bacteria interaction networks across healthy human bodies by leveraging previously published shotgun sequence datasets of purified viral metagenomes (viromes) paired with bacteria-dominated whole community metagenomes. Our study contained three datasets that explored the impact of diet on the healthy human gut virome [@Minot:2011ez], the impact of anatomical location on the healthy human skin virome [@Hannigan:2015fz], and the viromes of monozygotic twins and their mothers [@Reyes:2010cwa; @Turnbaugh:2009ei]. We selected these datasets because their virome samples were subjected to virus-like particle (VLP) purification. To this end, they employed combinations of filtration, chloroform/DNase treatment, and cesium chloride gradients to eliminate organismal DNA and thereby allow for direct assessment of both the extracellular and fully-assembled intracellular virome **(Supplemental Figure \ref{SequenceStats} A-B)** [@Minot:2011ez, @Hannigan:2015fz, @Reyes:2010cwa; @Turnbaugh:2009ei]. While the whole metagenomic shotgun sequence samples were not subjected to purification, they primarily consisted of bacteria [@Minot:2011ez; @Hannigan:2015fz; @Reyes:2010cwa; @Turnbaugh:2009ei].

The bacterial and viral sequences from these studies were quality filtered and assembled into contigs. We further grouped the related bacterial and phage contigs into operationally defined units based on their k-mer frequencies and co-abundance patterns, similar to previous reports **(Supplemental Figure \ref{ContigStats} - \ref{ClusterStats})** [@Roux:2016cc]. We referred to these operationally defined groups of related contigs as operational genomic units (OGUs). Each OGU represented a genomically similar sub-population of either bacteria or phages. Contig lengths within clusters ranged between $10^{3}$ and $10^{5.5}$ bp **(Supplemental Figure \ref{ContigStats} - \ref{ClusterStats})**.

## Evaluating the Model to Predict Phage-Bacteria Interactions
We predicted which phage OGUs infected which bacterial OGUs using a random forest model trained on experimentally validated infectious relationships from six previous publications [@Jensen:1998vh;@Malki:2015tm;@Schwarzer:2012ez;@Kim:2012dh;@Matsuzaki:1992gw;@Edwards:2015iz]. Only bacteria and phages were used in the model. The training set contained 43 diverse bacterial species and 30 diverse phage strains, including both broad and specific ranges of infection **(Supplemental Figure \ref{ValidationOverview} A - B)**. Phages with linear and circular genomes, as well as ssDNA and dsDNA genomes, were included in the analysis. Because we used DNA sequencing studies, RNA phages were not considered **(Supplemental Figure \ref{ValidationOverview} C-D)**. This training set included both positive relationships (a phage infects a bacterium) and negative relationships (a phage does not infect a bacterium). This allowed us to validate the false positive and false negative rates associated with our candidate models, thereby building upon previous work that only considered positive relationships [@Edwards:2015iz].

Four phage and bacterial genomic features were used in a random forest model to predict infectious relationships between bacteria and phages: 1) genome nucleotide similarities, 2) gene amino acid sequence similarities, 3) bacterial Clustered Regularly Interspaced Short Palindromic Repeat (CRISPR) spacer sequences that target phages, and 4) similarity of protein families associated with experimentally identified protein-protein interactions [@Orchard:2014hq]. The resulting random forest model was assessed and the area under its receiver operating characteristic (ROC) curve was 0.846, the model sensitivity was 0.829, and specificity was 0.767 **(Figure \ref{RocCurve} A)**. The most important predictor in the model was amino acid similarity between genes, followed by nucleotide similarity of whole genomes **(Figure \ref{RocCurve} B)**. Protein family interactions were moderately important to the model, and CRISPRs were largely uninformative, due to the minimal amount of identifiable CRISPRs in the dataset and their redundancy with the nucleotide similarity methods **(Figure \ref{RocCurve} B)**. Approximately one third of the training set relationships yielded no score and therefore were unable to be assigned an interaction prediction **(Figure \ref{RocCurve} C)**.

We used our random forest model to classify the relationships between bacteria and phage operational genomic units, which were then used to build the interactive network. The master network contained the three studies as sub-networks, which themselves each contained sub-networks for each sample **(Figure \ref{RocCurve} D)**. Metadata including study, sample ID, disease, and OGU abundance within the community were stored in the master network for parsing in downstream analyses **(Supplemental Figure \ref{NetworkDiagram})**. The master network was highly connected and contained 72,287 infectious relationships among 578 nodes, representing 298 phages and 280 bacteria. Although the network was highly connected, not all relationships were present in all samples. As relationships were weighted by the relative abundances of their associated bacteria and phages, lowly abundant relationships could be present but not highly abundant. Like the master network, the skin network exhibited a diameter of 4 (measure of graph size; the greatest number of traversed vertices required between two vertices) and included 99.7% and 99.8% of the master network nodes and edges, respectively **(Figure \ref{RocCurve} E - F)**. The phages and bacteria in the gut diet and twin sample sets were more sparsely related: each contained fewer than 150 vertices, fewer than 20,000 relationships, and diameters of 3 **(Figure \ref{RocCurve} E - F)**.

## Role of Diet & Obesity in Gut Microbiome Connectivity

Diet is a major environmental factor that influences resource availability and gut microbiome composition and diversity, including bacteria and phages [@Minot:2011ez; @Turnbaugh:2009hf; @David:2014cl]. Previous work in isolated culture-based systems has suggested that changes in nutrient availability are associated with altered phage-bacteria network structures [@Poisot:2011jc], although this has yet to be tested in humans. We therefore hypothesized that a change in diet would also be associated with a change in virome-microbiome network structure in the human gut.

We evaluated the diet-associated differences in gut virome-microbiome network structure by quantifying how central each sample's network was on average. We accomplished this by utilizing two common centrality metrics: degree centrality and closeness centrality. Degree centrality, the simplest centrality metric, was defined as the number of connections each phage made with each bacterium. We supplemented measurements of degree centrality with measurements of closeness centrality. Closeness centrality is a metric of how close each phage or bacterium is to all of the other phages and bacteria in the network. A higher closeness centrality suggests that the effects of genetic information or altered abundance would be more impactful to all other microbes in the system. A network with higher average closeness centrality also indicates an overall greater degree of connections, which suggests a greater resilience against instability. We used this information to calculate the average connectedness per sample, which was corrected for the maximum potential degree of connectedness.

We found that the gut microbiome network structures associated with high-fat diets were less connected than those of low-fat diets **(Figure \ref{dietnetworks} A-B)**. Tests for statistical differences were not performed due to the small sample size. High-fat diets exhibited reduced degree centrality **(Figure \ref{dietnetworks} A)**, suggesting bacteria in high-fat environments were targeted by fewer phages and that phage tropism was more restricted. High-fat diets also exhibited decreased closeness centrality **(Figure \ref{dietnetworks} B)**, indicating that bacteria and phages were more distant from other bacteria and phages in the community. This would make genetic transfer and altered abundance of a given phage or bacterium less capable of impacting other bacteria and phages within the network.

In addition to diet, obesity was found to influence network structure. Obesity-associated networks demonstrated a higher degree centrality **(Figure \ref{dietnetworks} C)**, but less closeness centrality than the healthy-associated networks **(Figure \ref{dietnetworks} D)**. These results suggested that the obesity-associated networks are less connected, having microbes further from all other microbes within the community.

## Individuality of Microbial Networks
Skin and gut community membership and diversity are highly personal, with people remaining more similar to themselves than to other people over time [@Grice:2009ee; @Hannigan:2015fz; @Minot:2013ih]. We therefore hypothesized that this personal conservation extended to microbiome network structure. We addressed this hypothesis by calculating the degree of dissimilarity between each subject's network, based on phage and bacteria abundance and centrality. We quantified phage and bacteria centrality within each sample graph using the weighted eigenvector centrality metric. This metric defines central phages as those that are highly abundant ($A_{O}$ as defined in the methods) and infect many distinct bacteria which themselves are abundant and infected by many other phages. Similarly, bacterial centrality was defined as those bacteria that were both abundant and connected to numerous phages that were themselves connected to many bacteria. We then calculated the similarity of community networks using the weighted eigenvector centrality of all nodes between all samples. Samples with similar network structures were interpreted as having similar capacities for maintaining stability and transmitting genetic material.

We used this network dissimilarity metric to test whether microbiome network structures were more similar within people than between people over time. We found that gut microbiome network structures clustered by person (ANOSIM p-value = 0.005, R = 0.958, **Figure \ref{intradiv} A**). Network dissimilarity within each person over the 8-10 day sampling period was less than the average dissimilarity between that person and others, although this difference was not statistically significant (p-value = 0.125, **Figure \ref{intradiv} B**). The lack of statistical confidence was likely due to the small sample size of this dataset. Although there was evidence for gut network conservation among individuals, we found no evidence for conservation of gut network structures within families. The gut network structures were not more similar within families (twins and their mothers; intrafamily) compared to other families (inter-family) (p-value = 0.312, **Figure \ref{intradiv} C**).

Skin microbiome network structure was strongly conserved within individuals (p-value < 0.001, **Figure \ref{intradiv} D**). This distribution was similar when separated by anatomical sites. Most sites were statistically significantly more conserved within individuals **(Supplemental Figure \ref{allskin})**.

## Association Between Environmental Stability and Network Structure Across the Human Skin Landscape
Extensive work has illustrated differences in diversity and composition of the healthy human skin microbiome between anatomical sites, including bacteria, virus, and fungal communities [@Grice:2009ee; @Findley:2013jf; @Hannigan:2015fz]. These communities vary by degree of skin moisture, oil, and environmental exposure. As viruses are known to influence microbial diversity and community composition, we hypothesized that microbe-virus network structure would be specific to anatomical sites, as well. To test this, we evaluated the changes in network structure between anatomical sites within the skin dataset.

The average centrality of each sample was quantified using the weighted eigenvector centrality metric. Intermittently moist skin sites (dynamic sites that fluctuate between being moist and dry) were significantly less connected than the more stable moist and sebaceous environments (p-value < 0.001, **Figure \ref{skinnetwork} A)**. Also, skin sites that were occluded from the environment were much more highly connected than those that were constantly exposed to the environment or only intermittently occluded (p-value < 0.001, **Figure \ref{skinnetwork} B)**.

To supplement this analysis, we compared the network signatures using the centrality dissimilarity approach described above. The dissimilarity between samples was a function of shared relationships, degree of centrality, and bacteria/phage abundance. When using this supplementary approach, we found that network structures significantly clustered by moisture, sebaceous, and intermittently moist status **(Figure \ref{skinnetwork} C,E)**. Occluded sites were significantly different from exposed and intermittently occluded sites, but there was no difference between exposed and intermittently occluded sites **(Figure \ref{skinnetwork} D,F)**. These findings provide further support that skin microbiome network structure differs significantly between skin sites.

# Discussion
Foundational work has provided a baseline understanding of the human microbiome by characterizing bacterial and viral diversity across the human body [@Grice:2009eea; @Findley:2013jf; @Hannigan:2015fz; @Costello:2009im, @Consortium:2012iz; @Schloss:2005hz; @Minot:2011ez]. Here, we offer an initial understanding of how phage-bacteria networks differ throughout the human body, so as to provide a baseline for future studies of how and why microbiome networks differ in disease states. We developed and implemented a network-based analytical model to evaluate the basic properties of the human microbiome through bacteria and phage relationships, instead of membership or diversity alone. This enabled the application of network theory to provide a new perspective on complex ecological communities. We utilized metrics of connectivity to model the extent to which communities of bacteria and phages interact through mechanisms such as horizontal gene transfer, modulated bacterial gene expression, and alterations in abundance.

Just as gut microbiome and virome composition and diversity are conserved in individuals [@Hannigan:2015fz; @Grice:2009eea; @Findley:2013jf; @Minot:2013ih], gut and skin microbiome network structures were conserved within individuals over time. Gut network structure was not conserved among family members. These findings suggested that the community properties inferred from microbiome interaction network structures, such as stability, the potential for horizontal gene transfer between members, and co-evolution of populations, were person-specific. These properties may be impacted by personal factors ranging from the body's immune system to external environmental conditions, such as climate and diet.

The ability of environmental conditions to shape gut and skin microbiome interaction network structure was further supported by our finding that diet and skin location were associated with altered network structures. We found evidence that diet was sufficient to alter gut microbiome network connectivity. Although our sample size was small, our findings provided evidence that high-fat diets were less connected than low-fat diets and that high-fat diets therefore may lead to less stable communities with a decreased ability for microbes to directly influence one another. We supported this finding with the observation that obesity may have been associated with decreased network connectivity. Together these findings suggest the food we eat may not only impact which microbes colonize our guts, but may also impact their  interactions with infecting phages. Further work will be required to characterize these relationships with a larger cohort.

In addition to diet, the skin environment also influenced the microbiome interaction network structure. Network structure differed between environmentally exposed and occluded skin sites. The sites under greater environmental fluctuation and exposure (the exposed and intermittently exposed sites) were less connected and therefore were predicted to have a higher propensity for instability. Likewise, intermittently moist sites demonstrated less connectedness than the more stable moist and sebaceous sites. Together these data suggested that body sites under greater degrees of fluctuation harbored less connected, potentially less stable microbiomes. This points to a link between microbiome and environmental stability and warrants further investigation.

While these findings take us an important step closer to understanding the microbiome through interspecies relationships, there are caveats to and considerations regarding the approach. First, as with most classification models, the infection classification model developed and applied is only as good as its training set -- in this case, the collection of experimentally-verified positive and negative infection data, where genomes of all members are fully sequenced. Large-scale experimental screens for phage and bacteria infectious interactions that report high-confidence negative interactions (i.e., no infection) are desperately needed, as they would provide more robust model training and improved model performance. Furthermore, just as we have improved on previous modeling efforts, we expect that new and creative scoring metrics will be integrated into this model to improve future performance.

Second, although our analyses offer an informative proof of concept, this work was done retrospectively and relied on existing data up to seven years old. These archived datasets were limited by the technology and costs of the time. This resulted in small sequencing effort (as compared to today's dataset sizes) and thus datasets that were sub-optimally powered for statistical analyses. Further, two studies, the diet and twin studies, relied on multiple displacement amplification (MDA) in their library preparations--an approach used to overcome the large nucleic acids requirements typical of older sequencing library generation protocols. It is now known that MDA results in significant biases in microbial community composition [@Yilmaz:2010jb], as well as toward ssDNA viral genomes [@Kim:2008to; @Kim:2011hp], thus rendering the resulting microbial and viral metagenomes non-quantitative. Future work that employs larger sequence datasets and that avoids the use of bias-inducing amplification steps will build on and validate our findings, as well as inform the design and interpretation of further studies. 

Finally, the networks in this study were built using operational genomic units (OGUs), which represented groups of highly similar bacteria or phage genomes or genome fragments as clustered sub-populations. Similar clustering definition and validation methods, both computational and experimental, have been implemented in other metagenomic sequencing studies, as well [@Minot:2012ed; @Deng:2014eb; @Brum:2015iaa; @Roux:2016cc]. These approaches could offer yet another level of sophistication to our network-based analyses. While this operationally defined clustering approach allows us to study whole community networks, our ability to make conclusions about interactions among specific phage or bacterial species or populations is inherently limited. Future work must address this limitation, e.g., through improved binning methods and deeper metagenomic shotgun sequencing, but most importantly through an improved conceptual framing of what defines ecologically and evolutionarily cohesive units for both phage and bacteria [@Polz:2006fi]. Defining operational genomic units and their taxonomic underpinnings (e.g., whether OGU clusters represent genera or species) is an active area of work critical to the utility of this approach. As a first step, phylogenomic analyses have been performed to cluster cyanophage isolate genomes into informative groups using shared gene content, average nucleotide identity of shared genes, and pairwise differences between genomes [@Gregory:2016cg]. Such population-genetic assessment of phage evolution, coupled with the ecological implications of genome heterogeneity, will inform how to define nodes in future iterations of the ecological network developed here.

Together our work takes an initial step towards defining bacteria-virus interaction profiles as a characteristic of human-associated microbial communities. This approach revealed the impacts that different human environments (e.g., the skin and gut) can have on microbiome connectivity. By focusing on relationships between bacterial and viral communities, they are studied as the interacting cohorts they are, rather than as independent entities. While our developed bacteria-phage interaction framework is a novel conceptual advance, the microbiome also consists of archaea and small eukaryotes, including fungi and *Demodex* mites [@Hannigan:2013im; @Grice:2011gy]--all of which can interact with human immune cells and other non-microbial community members [@Round:2009bz]. Future work will build from our approach and include these additional community members and their diverse interactions and relationships (e.g., beyond phage-bacteria). This will result in a more robust network and a more holistic understanding of the evolutionary and ecological processes that drive the assembly and function of the human-associated microbiome.

# Materials & Methods

## Data Availability
All associated source code is available on GitHub at the following repository:

https://github.com/SchlossLab/Hannigan_ConjunctisViribus_mSystems_2017

## Data Acquisition & Quality Control
Raw sequencing data and associated metadata were acquired from the NCBI sequence read archive (SRA). Supplementary metadata were acquired from the same SRA repositories and their associated manuscripts. The gut virome diet study (SRA: `SRP002424`), twin virome studies (SRA: `SRP002523`; `SRP000319`), and skin virome study (SRA: `SRP049645`) were downloaded as `.sra` files. Sequencing files were converted to `fastq` format using the `fastq-dump` tool of the NCBI SRA Toolkit (v2.2.0). Sequences were quality trimmed using the Fastx toolkit (v0.0.14) to exclude bases with quality scores below 33 and shorter than 75 bp [@FASTXToolkit:wr]. Paired end reads were filtered to exclude sequences missing their corresponding pair using the `get_trimmed_pairs.py` script available in the source code.

## Contig Assembly
Contigs were assembled using the Megahit assembly program (v1.0.6) [@Li:2016kd]. A minimum contig length of 1 kb was used. Iterative k-mer stepping began at a minimum length of 21 and progressed by 20 until 101. All other default parameters were used.

## Contig Abundance Calculations
Contigs were concatenated into two master files prior to alignment, one for bacterial contigs and one for phage contigs. Sample sequences were aligned to phage or bacterial contigs using the Bowtie2 global aligner (v2.2.1) [@Langmead:2012jh]. We defined a mismatch threshold of 1 bp and seed length of 25 bp. Sequence abundance was calculated from the Bowtie2 output using the `calculate_abundance_from_sam.pl` script available in the source code.

## Operational Genomic Unit Binning
Contigs often represent large fragments of genomes. In order to reduce redundancy and the resulting artificially inflated genomic richness within our dataset, it was important to bin contigs into operational units based on their similarity. This approach is conceptually similar to the clustering of related 16S rRNA sequences into operational taxonomic units (OTUs), although here we are clustering contigs into operational genomic units (OGUs) [@Schloss:2005hz].

Contigs were clustered using the CONCOCT algorithm (v0.4.0) [@Alneberg:2014fc]. Because of our large dataset and limits in computational efficiency, we randomly subsampled the dataset to include 25% of all samples, and used these to inform contig abundance within the CONCOCT algorithm. CONCOCT was used with a maximum of 500 clusters, a k-mer length of four, a length threshold of 1 kb, 25 iterations, and exclusion of the total coverage variable.

OGU abundance ($A_{O}$) was obtained as the sum of the abundance of each contig ($A_{j}$) associated with that OGU. The abundance values were length corrected such that:

$$ { A }_{ O }=\frac { { 10 }^{ 7 }\sum _{ j=1 }^{ k }{ { A }_{ j } }  }{ \sum _{ j=1 }^{ k }{ { L }_{ j } }  } $$

Where `L` is the length of each contig `j` within the OGU.

## Phage OGU Identification
To confirm a lack of phage sequences in the bacterial OGU dataset, we performed blast nucleotide alignment of the bacterial OGU representative sequences using an e-value < $10^{-25}$, which was stricter than the $10^{-10}$ threshold used in the random forest model below. We used a stricter threshold because we know there are genomic similarities between bacteria and phage OGUs from the interactive model, but we were interested in contigs with high enough similarity to references that they may indeed be from phages. 2% of the OGUs had nucleotide similarities to known bacteriophage genomes, although the alignments were short (a couple of kb) and represented a small fraction of the alignment sequences.

## Open Reading Frame Prediction
Open reading frames (ORFs) were identified using the Prodigal program (V2.6.2) with the meta mode parameter and default settings [@Hyatt:2012cy].

## Classification Model Creation and Validation
The classification model for predicting interactions was built using experimentally validated bacteria-phage infections or validated lack of infections from six studies [@Jensen:1998vh;@Malki:2015tm;@Schwarzer:2012ez;@Kim:2012dh;@Matsuzaki:1992gw;@Edwards:2015iz]. Associated reference genomes were downloaded from the European Bioinformatics Institute (see details in source code). The model was created based on the four metrics listed below.

The four scores were used as parameters in a random forest model to classify bacteria and bacteriophage pairs as either having infectious interactions or not. The classification model was built using the Caret R package (v6.0.73) [@caretClassificatio:_U2Lit_1]. The model was trained using five-fold cross validation with ten repeats. Pairs without scores were classified as not interacting. The model was optimized using the ROC value. The resulting model performance was plotted using the plotROC R package.

##### Identify Bacterial CRISPRs Targeting Phages
Clustered Regularly Interspaced Short Palindromic Repeats (CRISPRs) were identified from bacterial genomes using the PilerCR program (v1.06) [@Edgar:2007bh]. Resulting spacer sequences were filtered to exclude spacers shorter than 20 bp and longer than 65 bp. Spacer sequences were aligned to the phage genomes using the nucleotide BLAST algorithm with default parameters (v2.4.0) [@Camacho:2009fc]. The mean percent identity for each matching pair was recorded for use in our classification model.

##### Detect Matching Prophages within Bacterial Genomes
Temperate bacteriophages infect and integrate into their bacterial host's genome. We detected integrated phage elements within bacterial genomes by aligning phage genomes to bacterial genomes using the nucleotide BLAST algorithm and a minimum e-value of 1e-10. The resulting bitscore of each alignment was recorded for use in our classification model.

##### Identify Shared Genes Between Bacteria and Phages
As a result of gene transfer or phage genome integration during infection, phages may share genes with their bacterial hosts, providing us with evidence of phage-host pairing. We identified shared genes between bacterial and phage genomes by assessing amino acid similarity between the genes using the Diamond protein alignment algorithm (v0.7.11.60) [@Buchfink:2015ki]. The mean alignment bitscores for each genome pair were recorded for use in our classification model.

##### Protein - Protein Interactions
The final method used for predicting infectious interactions between bacteria and phages was the detection of pairs of genes whose proteins are known to interact. We assigned bacterial and phage genes to protein families by aligning them to the Pfam database using the Diamond protein alignment algorithm. We then identified which pairs of proteins were predicted to interact using the Pfam interaction information within the Intact database [@Orchard:2014hq]. The mean bitscores of the matches between each pair were recorded for use in the classification model.

## Interaction Network Construction
The bacteria and phage operational genomic units (OGUs) were scored using the same approach as outlined above. The infectious pairings between bacteria and phage OGUs were classified using the random forest model described above. The predicted infectious pairings and all associated metadata were used to populate a graph database using Neo4j graph database software (v2.3.1) [@Neoj:Fuwr6PBN]. This network was used for downstream community analysis.

## Centrality Analysis
We quantified the centrality of graph vertices using three different metrics, each of which provided different information graph structure. When calculating these values, let $G(V,E)$ be an undirected, unweighted graph with $|V|=n$ nodes and $|E|=m$ edges. Also, let $\mathbf{A}$ be its corresponding adjacency matrix with entries $a_{ij} = 1$ if nodes $V_i$ and $V_j$ are connected via an edge, and $a_{ij} = 0$ otherwise.

Briefly, the **closeness centrality** of node $V_i$ is calculated taking the inverse of the average length of the shortest paths (`d`) between nodes $V_i$ and all the other nodes $V_j$. Mathematically, the closeness centrality of node $V_i$ is given as:

$$ { C }_{ C }\left( { V }_{ i } \right) ={ \left( \sum _{ j=1 }^{ n }{ d\left( { V }_{ i },{ V }_{ j } \right)  }  \right)  }^{ -1 } $$

The distance between nodes (`d`) was calculated as the shortest number of edges required to be traversed to move from one node to another.

Intuitively, the **degree centrality** of node $V_i$ is defined as the number of edges that are incident to that node:

$$ { C }_{ D }\left( { V }_{ i } \right) =\sum _{ j=1 }^{ n }{ { a }_{ ij } } $$

where $a_{ij}$ is the $ij^{th}$ entry in the adjacency matrix $\mathbf{A}$.

The eigenvector centrality of node $V_i$ is defined as the $i^{th}$ value in the first eigenvector of the associated adjacency matrix $\mathbf{A}$. Conceptually, this function results in a centrality value that reflects the connections of the vertex, as well as the centrality of its neighboring vertices.

The **centralization** metric was used to assess the average centrality of each sample graph $\mathbf{G}$. Centralization was calculated by taking the sum of each vertex $V_{i}$'s centrality from the graph maximum centrality $C_{w}$, such that:

$$ C\left( G \right) =\frac { \sum _{ i=1 }^{ n }{ Cw -c\left( { V }_{ i } \right)  }  }{ { T } }  $$

The values were corrected for uneven graph sizes by dividing the centralization score by the maximum theoretical centralization (`T`) for a graph with the same number of vertices.

Degree and closeness centrality were calculated using the associated functions within the igraph R package (v1.0.1) [@Theigraphsoftware:vh].

## Network Relationship Dissimilarity
We assessed similarity between graphs by evaluating the shared centrality of their vertices, as has been done previously. More specifically, we calculated the dissimilarity between graphs $G_{i}$ and $G_{j}$ using the Bray-Curtis dissimilarity metric and eigenvector centrality values such that:

$$ B\left( { G }_{ i },{ G }_{ j } \right) =1-\frac { 2{ C }_{ ij } }{ { C }_{ i }+{ C }_{ j } } $$

Where $C_{ij}$ is the sum of the lesser centrality values for those vertices shared between graphs, and $C_{i}$ and $C_{j}$ are the total number of vertices found in each graph. This allows us to calculate the dissimilarity between graphs based on the shared centrality values between the two graphs.

## Statistics and Comparisons
Differences in intrapersonal and interpersonal network structure diversity, based on multivariate data, were calculated using an analysis of similarity (ANOSIM). Statistical significance of univariate Eigenvector centrality differences were calculated using a paired Wilcoxon test.

Statistical significance of differences in univariate eigenvector centrality measurements of skin virome-microbiome networks were calculated using a pairwise Wilcoxon test, corrected for multiple hypothesis tests using the Holm correction method. Multivariate eigenvector centrality was measured as the mean differences between cluster centroids, with statistical significance measured using an ANOVA and post hoc Tukey test.

# Acknowledgments
We thank the members of the Schloss lab for their underlying contributions.

# Funding Information
GDH was supported in part by the Molecular Mechanisms in Microbial Pathogenesis Training Program (T32 AI007528). GDH and PDS were supported in part by funding from the NIH (P30DK034933, U19AI09087, and U01AI124255).

# Disclosure Declaration
The authors report no conflicts of interest.

\newpage

# Figures

![**Summary of Multi-Study Network Model.** *(A) Average ROC curve used to create the microbiome-virome infection prediction model. (B) Importance scores associated with the metrics used in the random forest model to predict relationships between bacteria and phages. The importance score is defined as the mean decrease in accuracy of the model when a feature (e.g. Pfam) is excluded. (C) Proportions of samples included (gray) and excluded (red) in the model. Samples were excluded from the model because they did not yield any scores. Those interactions without scores were defined as not having interactions. (D) Bipartite visualization of the resulting phage-bacteria network. This network includes information from all three published studies. (E) Network diameter (measure of graph size; the greatest number of traversed vertices required between two vertices), (F) number of vertices, and (G) number of edges (relationships) for the total network (yellow) and the individual study sub-networks (diet study = red, skin study = green, twin study = orange).* \label{RocCurve}](../figures/rocCurves.pdf){ width=90% }

\newpage

![**Impact of Diet and Obesity on Gut Network Structure.** *(A) Quantification of average degree centrality (number of edges per node) and (B) closeness centrality (average distance from each node to every other node) of gut microbiome networks of subjects limited to exclusively high-fat or low-fat diets. Lines represent the mean degree of centrality for each diet. (C) Quantification of average degree centrality and (D) closeness centrality between obese and healthy adult women.*\label{dietnetworks}](../figures/dietnetworks.pdf){ width=90% }

\newpage

![**Intrapersonal vs Interpersonal Network Dissimilarity Across Different Human Systems.** *(A) NMDS ordination illustrating network dissimilarity between subjects over time. Each sample is colored by subject, with each sample pair collected 8-10 days apart. Dissimilarity was calculated using the Bray-Curtis metric based on abundance weighted eigenvector centrality signatures, with a greater distance representing greater dissimilarity in bacteria and phage centrality and abundance. (B) Quantification of gut network dissimilarity within the same subject over time (intrapersonal) and the mean dissimilarity between the subject of interest and all other subjects (interpersonal). The p-value is also provided. (C) Quantification of gut network dissimilarity within subjects from the same family (intrafamily) and the mean dissimilarity between subjects within a family and those of other families (interfamily). The p-value is also provided. (D) Quantification of skin network dissimilarity within the same subject and anatomical location over time (intrapersonal) and the mean dissimilarity between the subject of interest and all other subjects at the same time and the same anatomical location (interpersonal). P-value was calculated using a paired Wilcoxon test.*\label{intradiv}](../figures/intrapersonal_diversity.pdf){ width=90% }

![**Impact of Skin Micro-Environment on Microbiome Network Structure.**  *(A) Notched box-plot depicting differences in average eigenvector centrality between moist, intermittently moist, and sebaceous skin sites and (B) occluded, intermittently occluded, and exposed sites. Notched box-plots were created using ggplot2 and show the median (center line), the inter-quartile range (IQR; upper and lower boxes), the highest and lowest value within 1.5 \* IQR (whiskers), outliers (dots), and the notch which provides an approximate 95% confidence interval as defined by 1.58 \* IQR / sqrt(n). (C) NMDS ordination depicting the differences in skin microbiome network structure between skin moisture levels and (D) occlusion. Samples are colored by their environment and their dissimilarity to other samples was calculated as described in figure \ref{intradiv}. (E) The statistical differences of networks between moisture and (F) occlusion status were quantified with an anova and post hoc Tukey test. Cluster centroids are represented by dots and the extended lines represent the associated 95% confidence intervals. Significant comparisons (p-value < 0.05) are colored in red, and non-significant comparisons are gray.*\label{skinnetwork}](../figures/skinplotresults.pdf){ width=75% }

\newpage

# Supplemental Figures

\beginsupplement

![**Sequencing Depth Summary.** *Number of sequences that aligned to (A) Phage and (B) Bacteria operational genomic units per sample and colored by study.*\label{SequenceStats}](../figures/SequenceAbund.pdf){ width=80% }

\newpage

![**Contig Summary Statistics.** *Scatter plot heat map with each hexagon representing the abundance of contigs. Contigs are organized by length on the x-axis and the number of aligned sequences on the y-axis.*\label{ContigStats}](../figures/ContigStats.pdf){ width=50% }

\newpage

![**Operational Genomic Unit Summary Statistics.** *Scatter plot with operational genomic unit clusters organized by average contig length within the cluster on the x-axis and the number of contigs in the cluster on the y-axis. Operational genomic units of (A) bacteriophages and (B) bacteria are shown.*\label{ClusterStats}](../figures/ClusterStats.pdf){ width=80% }

\newpage

![**Summary information of validation dataset used in the interaction predictive model.** *A) Categorical heat-map highlighting the experimentally validated positive and negative interactions. Only bacteria species are shown, which represent multiple reference strains. Phages are labeled on the x-axis and bacteria are labeled on the y-axis. B) Quantification of bacterial host strains known to exist for each phage. C) Genome strandedness and D) linearity of the phage reference genomes used for the dataset.*\label{ValidationOverview}](../figures/BenchmarkDataset.pdf){ width=100% }

\newpage

![**Structure of the interactive network.** *Metadata relationships to samples (Phage Sample ID and Bacteria Sample ID) included the associated time point, the study, the subject the sample was taken from, and the associated disease. Infectious interactions were recorded between phage and bacteria operational genomic units (OGUs). Sequence count abundance for each OGU within each sample was also recorded.*\label{NetworkDiagram}](../figures/graphdatabasediagram.pdf){ width=50% }

\newpage

![**Intrapersonal vs Interpersonal Dissimilarity of the Skin.** *Quantification of skin network dissimilarity within the same subject and anatomical location over time (intrapersonal) and the mean dissimilarity between the subject of interest and all other subjects at the same time and the same anatomical location (interpersonal), separated by each anatomical site (forehead [Fh], palm [Pa], toe web [Tw], umbilicus [Um], antecubital fossa [Ac], axilla [Ax], and retroauricular crease [Ra]). P-value was calculated using a paired Wilcoxon test.*\label{allskin}](../figures/intraallskin.pdf){ width=75% }

\newpage

# References
