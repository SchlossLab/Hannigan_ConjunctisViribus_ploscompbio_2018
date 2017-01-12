library(DiagrammeR)

# Create a simple NDF
nodevector <- c(
  "Study",
  "Disease",
  "Subject ID",
  "Phage Sample ID",
  "Bacterial Sample ID",
  "Time Point",
  "Phage OGU",
  "Bacteria OGU")

nodes <-
  create_node_df(
    n = length(nodevector),
    label = nodevector,
    fixedsize = FALSE,
    fillcolor = "white",
    fontcolor = "black",
    shape = "oval",
    fontname = "Helvetica",
    penwidth = 0.25,
    color = "black",
    fontsize = 7)

# Create a simple EDF
edges <-
  create_edge_df(
    from = c(
      7,
      4,
      5,
      3,
      3,
      2,
      2,
      1,
      1,
      1,
      6,
      6
    ),
    to = c(
      8,
      7,
      8,
      4,
      5,
      4,
      5,
      4,
      5,
      2,
      4,
      5
    ),
    color = "black",
    penwidth = 0.25,
    label = c("Predicted Infection", "Abundance", "Abundance"),
    fontsize = 7,
    fontname = "Helvetica"
  )

# Create the graph object,
# incorporating the NDF and
# the EDF, and, providing
# some global attributes
graph <-
  create_graph(
    nodes_df = nodes,
    edges_df = edges)

# render_graph(graph)

# View the graph
export_graph(
  graph,
  file_name = "./figures/graphdatabasediagram.pdf",
  file_type = "pdf"
)
