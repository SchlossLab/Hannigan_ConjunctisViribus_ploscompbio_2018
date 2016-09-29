library(DiagrammeR)
library(DiagrammeRsvg)
library(magrittr)

# Create a simple NDF
nodes <-
  create_nodes(
    nodes = c("Study",
      "Disease",
      "SampleID",
      "Phage X",
      "Phage Y",
      "Bacteria X",
      "Bacteria Y"))

# Create a simple EDF
edges <-
  create_edges(
    from = c(
      "Study",
      "Disease",
      "SampleID",
      "SampleID",
      "SampleID",
      "SampleID",
      "Phage X",
      "Phage X",
      "Phage X",
      "Bacteria X"),
    to = c(
      "Disease",
      "SampleID",
      "Phage X",
      "Phage Y",
      "Bacteria X",
      "Bacteria Y",
      "Bacteria X",
      "Bacteria Y",
      "Phage Y",
      "Bacteria Y"),
    label = c(
      "",
      "",
      "Relative\nAbundance",
      "Relative\nAbundance",
      "Relative\nAbundance",
      "Relative\nAbundance",
      "Predicted\nInfection",
      "Predicted\nInfection",
      "K-mer\nDistance",
      "K-mer\nDistance")
    )

# Create the graph object,
# incorporating the NDF and
# the EDF, and, providing
# some global attributes
graph <-
  create_graph(
    nodes_df = nodes,
    edges_df = edges,
    node_attrs = "fontname = Helvetica",
    edge_attrs = "color = gray20")

# View the graph
export_graph(
  graph,
  file_name = "../figures/graphdatabasediagram.pdf",
  file_type = "pdf"
)
