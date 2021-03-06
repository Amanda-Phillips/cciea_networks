% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/directed_network_collapse_confidential_late.R
\name{collapse_confidential_late}
\alias{collapse_confidential_late}
\title{Collapse Confidential Fisheries, Late Season Directed Network}
\usage{
collapse_confidential_late(
  A,
  vessel_matrix,
  no_drop = c("DCRB_POT", "other_port", "no_fishing"),
  default_other = "mode"
)
}
\arguments{
\item{A}{confidential adjacency matrix from \code{gen_adj_matrix_late} function}

\item{vessel_matrix}{confidential vessel participation matrix from \code{gen_adj_matrix_late} function}

\item{no_drop}{specify which nodes \emph{not} to collapse (if confidential will just be dropped)}

\item{default_other}{when collapsing multiple fisheries into an "other" group, a single vessel can have multiple matrix values (-1,1,2). when this happens, default to a specific value, or use "mode"}
}
\value{
a list with (1) A: adjacency matrix with non-confidential data to create directed network, (2 & 3) vpf_2014 & vpf_2015: vessels participating in each fishery / aggregate in 2014-15 and 2015-16
}
\description{
Collapse confidential fisheries (< 3 vessels) in the late season directed
networks. Confidential Pot / Hook and Line fisheries are collapsed to an
'other, pot/hkl' fishery, unless a self-loop has more than three vessels.
If there are no confidential pot / hook and line fisheries, or if aggregating
those fisheries still results in participation of < 3 vessels, confidential
fisheries are collapsed into a more generic 'other' fishery. For Script 09b.
}
\examples{
Anew <- collapse_confidential_late(A=A,vessel_matrix = vesselmat, default_other=2)
}
