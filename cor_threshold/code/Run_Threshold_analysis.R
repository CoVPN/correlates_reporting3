
#-----------------------------------------------
# obligatory to append to the top of each script
renv::activate(project = here::here(".."))
 
#-----------------------------------------------

library(sl3)
library(SuperLearner)
library(data.table)
library(mvtnorm)
library(uuid)
library(doMC)
library(earth)
source(here::here("code", "params.R"))
source(here::here("code", "tmleThresh.R"))
source(here::here("code", "learners.R"))
source(here::here("code", "survivalThresh", "Threshold_survivalCR.R"))
source(here::here("code", "survivalThresh", "fitting_likelihood.R"))
source(here::here("code", "survivalThresh", "Pooled_hazards.R"))
source(here::here("code", "survivalThresh", "sl3_learner_helpers.R"))
source(here::here("code", "survivalThresh", "survival_helper_functions.R"))
source(here::here("code", "survivalThresh", "targeting_functions.R"))
source(here::here("code", "survivalThresh", "task_generators.R"))
 

 

#lrnr <- get_learner(fast_analysis = fast_analysis, include_interactions = include_interactions, covariate_adjusted = covariate_adjusted)
 
#lrnr <- Lrnr_glm$new()
#lrnr_N <-lrnr
#lrnr_C <-lrnr
#lrnr_A <-lrnr

# Runs threshold analysis and saves raw results.
#' @param marker Marker to run threshold analysis for
run_threshold_analysis <- function(marker, direction = "above") {
  print(marker)
  
    if("risk_score" %in% covariates) {
        form <- paste0("Y~h(.) + h(t,.) + h(A, .)")
    } else {
        form <- paste0("Y~h(.) + h(.,.)")

    }
  form <- paste0("Y~h(.) + h(t,.)  + h(A,.)")
    print(form)
    require(doMC)
    registerDoMC()
    ngrid_A <- 30
    lrnr_N <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(10,3), reduce_basis =1e-3, formula_hal = form, fit_control = list(n_folds = 10, parallel = TRUE))
    lrnr_C <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(5,1), reduce_basis=1e-3,  formula_hal = form, fit_control = list(n_folds = 10, parallel = TRUE))
    lrnr_A <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(5,1), reduce_basis=1e-3, fit_control = list(n_folds = 10, parallel = TRUE))
    if(fast_analysis) {
     ngrid_A <- 15
        print("fast analysis")
      form <- paste0("Y~h(.) + h(t,.)")
        lrnr_N <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(10,2), reduce_basis =1e-4, formula_hal = form, fit_control = list(n_folds = 10, parallel = TRUE))
        lrnr_C <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(9,2), reduce_basis=1e-4,  formula_hal = form, fit_control = list(n_folds = 10, parallel = TRUE))
        lrnr_A <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(10,3), reduce_basis=1e-4, fit_control = list(n_folds = 10, parallel = TRUE))
    }
 if(super_fast_analysis) {
  ngrid_A <- 10
        print("super fast analysis")
        form <- paste0("Y~h(.) + h(t,.)")
        lrnr_N <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(3,1), reduce_basis =1e-4, formula_hal = form, fit_control = list(n_folds = 10, parallel = TRUE))
        lrnr_C <- Lrnr_hal9001_custom$new(max_degree = 2, smoothness_orders = 0, num_knots = c(3,1), reduce_basis=1e-4,  formula_hal = form, fit_control = list(n_folds = 10, parallel = TRUE))
        lrnr_A <- Lrnr_hal9001_custom$new(max_degree = 1, smoothness_orders = 0, num_knots = c(3,1), reduce_basis=1e-4, fit_control = list(n_folds = 10, parallel = TRUE))
  }
    
  thresholds <- read.csv(here::here("data_clean", "Thresholds_by_marker", paste0("thresholds_", marker, ".csv")))
  thresholds <- as.vector(unlist(thresholds[, 1]))
  #time <- marker_to_time[[marker]]
  data_full <- read.csv(here::here("data_clean", paste0("data_firststage_", COR, ".csv")))
 

  ####################################################
  # Run thresholdTMLE
  ####################################################
   print("HERE")
  if(direction=="above") {
    print(thresholds)
      #esttmle_full <- survivalThresh(as.data.table(data_full), trt = marker, Ttilde = "Ttilde",Delta = "Delta", J = "J", covariates = covariates, target_times = unique(data_full$target_time),cutoffs_A = thresholds, cutoffs_J = 1, type_J = "equal", lrnr =lrnr, lrnr_A = lrnr_A, lrnr_N = lrnr_N, lrnr_C = lrnr_C, biased_sampling_group= NULL, biased_sampling_indicator = "TwophasesampInd", weights_var = "wt", monotone_decreasing = T, ngrid_A = ngrid_A )
      node_list <- list("W" = covariates, "A" = marker, "Y" = "Delta", weights = "wt")
      lrnr <- Lrnr_sl$new(learners = Stack$new(
         Lrnr_glmnet$new(),
         Lrnr_gam$new(),
         Lrnr_earth$new(),
         Lrnr_mean$new()
       ), metalearner = Lrnr_cv_selector$new(loss_loglik_binomial))
       
      esttmle_full <- thresholdTMLE(data_full, node_list, thresholds = thresholds, biased_sampling_strata = NULL, biased_sampling_indicator = "TwophasesampInd", 
                                    lrnr_A = lrnr
                                      , lrnr_Y = lrnr
                                    , lrnr_Delta = Lrnr_glmnet$new(), monotone_decreasing = TRUE) 
        
  
  } else if(direction=="below") {
    stop("NO longer used")
      thresholds <- thresholds[-1]
      data_full[[marker]] <- -data_full[[marker]]
      esttmle_full <- survivalThresh(as.data.table(data_full), trt = marker, Ttilde = "Ttilde",Delta = "Delta", J = "J", covariates = covariates, target_times = unique(data_full$target_time),cutoffs_A = sort(-thresholds), cutoffs_J = 1, type_J = "equal", lrnr =lrnr, lrnr_A = lrnr_A, lrnr_N = lrnr_N, lrnr_C = lrnr_C, biased_sampling_group= NULL, biased_sampling_indicator = "TwophasesampInd", weights_var = "wt", monotone_decreasing = F, ngrid_A = min(15,ngrid_A) )
      esttmle_full[[1]][,1] <- - esttmle_full[[1]][,1]
      esttmle_full[[1]] <- esttmle_full[[1]][order(esttmle_full[[1]][,1]),]
      esttmle_full[[2]][,1] <- - esttmle_full[[2]][,1]
      esttmle_full[[2]] <- esttmle_full[[2]][order(esttmle_full[[2]][,1]),]

      
  }

  esttmle <- esttmle_full[[1]]
  
  direction_append <- ""
  if(direction=="below") {
      direction_append <- "_below"
  }
  print(direction_append)
  # Save estimates and CI of threshold-response function
  save("esttmle", file = here::here(
    "output",
    paste0("tmleThresh_",   COR, "_",marker, direction_append,".RData")
  ))
  write.csv(esttmle, file = here::here(
    "output",
    paste0("tmleThresh_",  COR, "_",marker,direction_append, ".csv")
  ), row.names = F)
  
  esttmle <- esttmle_full[[2]]
  save("esttmle", file = here::here(
    "output",
    paste0("tmleThresh_monotone_", COR, "_", marker,direction_append, ".RData")
  ))
  write.csv(esttmle, file = here::here(
    "output",
    paste0("tmleThresh_monotone_", COR, "_", marker,direction_append, ".csv")
  ), row.names = F)

  return(esttmle)
}

# print("WHATTTTTTTt")
#  print(markers)
# for (marker in markers) {
#   print(marker)
#     v <- run_threshold_analysis(marker, "below")
# }


for (marker in markers) {
     
  print(marker)
  v <- run_threshold_analysis(marker, "above")
}
