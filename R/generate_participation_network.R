#' Generate Participation Network
#'
#' Create a fisheries participation network. Based on original function by 
#' Emma Fuller; edits specified in comments.
#'
#' @param tickets fish tickets data frame
#' @param pcid_choose specify a port group
#' @param year_choose Specify a crab year
#' @param filter use the `min_vessels` and `min_contribution` objects to filter the data
#' @param filter_subgraph a filtering option from the original function that was turned off for Fisher et al.
#' @param min_vessels the minimum number of vessels participating in a fishery for that fishery to be retained in the network
#' @param min_contribution the minimum contribution (as a proportion) to total exvessel revenue for a fishery to be retained for a given vessel
#' @return non-confidential fisheries partition network as an igraph object
#' @examples
#' close_g <- participation_network_crabyear(close_dat, filter = TRUE, filter_subgraph = FALSE)
#' @export
participation_network_crabyear <- function(tickets, pcid_choose=NA, year_choose=NA, filter, filter_subgraph, min_vessels = 3, min_contribution = 0.10){
  if(!is.na(pcid_choose)){
    tickets = dplyr::filter(tickets, pcgroup %in% pcid_choose)
  }
  if(any(!is.na(year_choose))){
    tickets = dplyr::filter(tickets, crab_year %in% year_choose)
  }
  
  if(nrow(tickets)==0){
    return(NA)
  }
  # get total number of boats (MF 2/26/2019)
  fleet_size <- length(unique(filter(tickets, drvid!='NONE')))
  
  # create a df with 2 columns: SPGRPN2 (metier.name in Mary's code) and max_boats, the maximum boats that participated in the metier during the specified year(s)
  n_boats <- tickets %>% filter(drvid!='NONE') %>%
    group_by(crab_year, SPGRPN2) %>% #changed year to crab_year (MF 2/26/2019)
    summarise(n_boats = length(unique(drvid))) %>% #changed summarize to summarise, JS 11092018
    group_by(SPGRPN2) %>%
    summarise(max_boats = max(n_boats)) #changed summarize to summarise, JS
  
  # create a df where each column is a SPGRPN2, and values represent the total revenue for a boat in a crab year from that SPGRPN2
  boats <- tickets %>% filter(drvid != 'NONE') %>%
    group_by(drvid, SPGRPN2, crab_year) %>% #removed mutate; changed year to crab_year MF 2/26/2019
    summarise(revenue = sum(adj_revenue)) %>% #changed summarize to summarise, JS 11092018
    spread(SPGRPN2, revenue, fill = NA)
  boats <- as.data.frame(boats)
  rownames(boats) <- paste(boats$drvid, boats$crab_year, sep="_")
  boats$drvid <- NULL
  boats$crab_year <- NULL
  
  # remove the one boat that didn't sell catch (i.e. rev = 0)
  if(any(rowSums(boats,na.rm=T)==0)){boats <- boats[-which(rowSums(boats, na.rm=T)==0),]}
  
  # make a new df with annual % revenue from each metier for each boat
  percent_boats <- boats/rowSums(boats, na.rm = T)
  
  # find median contribution of fisheries to each vessel
  percent_contribution = apply(percent_boats, MARGIN = 2, FUN = function(x) median(x, na.rm=T))
  
  # process data: drop metiers if fewer than 3 boats participate
  # in any year, and have to be on average 25% of boats annual revenue
  
  if(filter){
    nb = as.numeric(min_vessels) # changed from 3 to f(x) argument
    percent = as.numeric(min_contribution) # changed from 0.25 to f(x) argument
  }else{
    nb = 0
    percent = 0
  }
  
  fishery_df = as.data.frame(percent_contribution)
  fishery_df$SPGRPN2 = rownames(fishery_df)
  rownames(fishery_df) <- NULL
  fish_df <- left_join(fishery_df, n_boats, by = 'SPGRPN2')
  # build adjacency matrix, where elements are frac rev fishery i * frac rev fishery j * total dollars (sum)
  fisheries <- fish_df$SPGRPN2[which(fish_df$max_boats>= nb & 
                                           fish_df$percent_contribution>=percent)] # updated 5/13/2019 from > to >=
  if(length(fisheries)==0){
    return(NA)
  }
  A <- matrix(ncol = length(fisheries), nrow = length(fisheries), data = 0)
  colnames(A) <- fisheries
  rownames(A) <- fisheries
  for(k in 1:nrow(boats)){
    
    for(i in 1:nrow(A)){
      frac_rev_i = percent_boats[k,fisheries[i]]
      if(is.na(frac_rev_i)){next} # if don't fish this, then can skip all other combos
      
      for(j in i:ncol(A)){
        frac_rev_j = percent_boats[k,fisheries[j]]
        if(is.na(frac_rev_j)){next}
        
        total_rev = boats[k, fisheries[i]] + boats[k, fisheries[j]]
        A[i,j] = A[i,j] + frac_rev_i * frac_rev_j * total_rev
      }
    }
    #if(k %% 1000 == 0){cat(paste(' iteration', k))}
  }
  
  # create graph
  g <- graph_from_adjacency_matrix(adjmatrix = A, mode = 'undirected', weighted = TRUE, diag= FALSE)
  vertex_size = sum(boats[,fisheries], na.rm=T)
  V(g)$size <- vertex_size #total revenue in all fisheries
  V(g)$percent_size = apply(percent_boats[,fisheries, drop=FALSE], MARGIN = 2, FUN = function(x) median(x, na.rm=T))
  V(g)$importance = V(g)$size*V(g)$percent_size #how much revenue from each fishery
  
  V(g)$fleet = fleet_size #total number of vessels in fishery (MF2/26/2019)
  
  ##########  changed 2/26/2019 ############
  # if filter_subgraph = TRUE, keep V which make up to 99% of revenue
  if(filter_subgraph){
    if(length(V(g))==1){
      big_g <- g
    }
    else{
      # calculate % cumulative revenue fisheries are responsible for
      size_df <- cbind(V(g), V(g)$importance) #changed from V(g)$size
      size_df <- size_df[order(size_df[,2], decreasing = T),]
      size_df <- cbind(size_df, cumsum(size_df[,2])/sum(size_df[,2]))
      
      big_g <- induced_subgraph(g, V(g)[V(g)[rownames(size_df)[which(size_df[,3]<.99)]]]) #IS THIS KEEPING THE RIGHT VERTICES??
    }
  }else{
    big_g <- g
  }
  return(big_g)
}
