#' @title utils.R
#' @description This is the R file containing all functions used for the genetic algorithm (GA)
#' package.  An OOP approach was taken to complete this algorithm.

init <- function(df, P){
  #' @title init (initialize)
  #' @description function outputs P random binary vectors of length c
  #' @param df (data.frame): the datasets with X and Y.
  #' @param P (int): number of candidates per generations
  #' @return generation(binary matrix P x c): P candidates
  c <- ncol(df) - 1
  return(as.data.frame(matrix(c(rep(0,c),sample(c(0,1),(P-2)*c,replace = T),rep(1,c)), nrow = P, byrow = T)))

  ## Notes.

  # 1. make sure we have all 0 and all 1 in the initial generation.
  # 2. what if weird number of P is entered? say very very small/large P.
  #     - n
  # return error.
}


training <- function(candidate, method, X, fitness_function, ...){
  #' @title training
  #' @description This function fits the method on candidates and return the fitness value of the candidate
  #' @param candidate (binary vector length c): on or off for each columns of X
  #' @param method: method for fitting lm/glm
  #' @param X (matrix n x (c+1)): data (n x c) and the last column is the value of y.
  #' @param fitness_function: error of the model
  #' @return fitness_value (float): fitness value of the model
  individual_training <- function(x){
    ynam <- colnames(X)[ncol(X)]
    if (sum(x)==0){
      fmla <- as.formula(paste(ynam, " ~ 1"))
      return(fitness_function(method(fmla, data = X,...)))
    }else{
      xnam <- colnames(X)[which(as.logical(x))]
      fmla <- as.formula(paste(ynam, " ~ ", paste(xnam, collapse= "+")))
      return(fitness_function(method(fmla, data = X,...)))
    }
  }
  return(apply(candidate, 1, individual_training))
}

select_parents <- function(fitness_values, mechanism=c("rank", "tournament"),random = TRUE, P, c){
  #' @title select_parents
  #' @description This function returns pairs of parents for breeding
  #' @param fitness_values (vector P): fitness_value of each of the candidate of the current generation
  #' @param P (int): number of candidates per generation
  #' @param mechanism: user defined rank-based selection mechanism,
  #'         must be one of c("replace_all","tournament", "partial_replace")
  #' @param random: A boolean value(T/F), "T" if choosing 1 parent selected proportional to fitness + 1 parent
  #'         random selected and "F" if 2 parents selected proportional to to fitness
  #' @param generation gap: proportion of the generation to be replaced by offspring
  #'   output:
  #' @return parents (matrix P x 2): each row is a pair of indices of parents
  #' @return candidate(P x c): Each row is a candidate model for breeding

  fitness_rank <- rank(fitness_values)
  fitness_phi <- fitness_rank/sum(fitness_rank)
  parent.pairs <- matrix(rep(0,ceiling(P/2)*2), ncol = 2)
  if (mechanism == "rank"){
    if (random == TRUE){
      i <- 0
      while(i <= ceiling(P/2)){
        parent.pairs.candidate <- c(sample.int(P, size = 1,prob = fitness_phi),
                                    sample.int(P, size = 1))
        if (sum(apply(parent.pairs, 1, identical, parent.pairs.candidate)) == 0){
          parent.pairs[i,] <- parent.pairs.candidate
          i <- i + 1
        }
      }
    }else{
      while(i <= ceiling(P/2)){
        parent.pairs.candidate <- sample.int(P,size = 2,prob = fitness_phi)
        if (sum(apply(parent.pairs, 1, identical, parent.pairs.candidate)) == 0){
          parent.pairs[i,] <- parent.pairs.candidate
          i <- i + 1
        }
      }
    }
  }else if (mechanism == "tournament"){
    tournament_sample <- rep(0,P)
    for (i in 1:P){
      tournament_sample[i] <- which.max(fitness_rank[sample.int(P, size = ceiling(P/4), replace = T)])
    }
    parent.pairs <- tournament_sample[!duplicated(t(combn(tournament_sample,2)))]
    parent.pairs <- parent.pairs[!rowSums(t(apply(parent.pairs, 1, duplicated))),][1:P,]
  }
  return(parent.pairs)

  # point:
  # 1. after selection, the paired parents should be different.
  # 2. avoid offsprings share the exact same gene.
}

breed <- function(candidate, c, parent.pairs, mu, crossover_points, fitness_values, Gap=1/4){
  #' @title breed
  #' @description This function returns P candidates of the next generation based on the pairs of parents.
  #' Crossover and mutation is also contained within this function.
  #' @param candidate Each row of this matrix corresponds to a candidate model of current generation.
  #' @param c The number of chromosomes for each candidate function.
  #' @param parent.pairs Matrix of parent breeding pairs, a result of the \emph{select_parents} function.
  #' @param mu (float) This is the mutation rate of chromosomes in each candidate function
  #' @param crossover_points Number of crossover points to be used in the bredding step.
  #' @param fitness_values These are calculated fitness values of the present generation.
  #' This comes in the form of a vector, and fitness values at a particular index corresponds
  #' to the candidate function of the same index in the candidate function
  #' @param Gap Generation gap for replacement of parents with offspring from each
  #' created iteration of the GA
  #' @return generation(binary matrix P x c): P candidates
  crossover <- function(candidate, c, parent.pairs, crossover_points){

    pos <- sort(sample(1:(c-1), crossover_points, replace = F))
    k <- unname(split(1:c, cumsum(seq_along(1:c) %in% pos))) # crossover point after k-th index
    # notes: input 1 <= crossover_points <= c-1. else return error. warning("crossover_point not proper")
    #print(paste("Splitting occurs after position", k))
    # crossover points split the chromosome into parts,
    # which we can express i-th part as chromosome[k_start[i], k[i]]
    offspring= data.frame()

    for (i in 1: nrow(parent.pairs)){
      parent1= candidate[parent.pairs[i, 1], ]
      parent2= candidate[parent.pairs[i, 2], ]
      temp1= c()
      temp2= c()
      #for odd j, the j-th part in parent 1 will stay in parent 1, same for part 2
      for (j in 1:(crossover_points + 1)){
        if (j %% 2 ==1){
          temp1= c(temp1, parent1[k[[j]]])
          temp2= c(temp2, parent2[k[[j]]])
        }
        #for odd j, the j-th part in parent 1 will change to parent 2(same for part 2)
        else if (j %% 2 ==0){
          temp1= c(temp1, parent2[k[[j]]])
          temp2= c(temp2, parent1[k[[j]]])
        }
      }
      offspring = rbind(offspring, temp1, temp2)
    }
    return(offspring)
  }


  #' mutation
  mutation <- function(offspring, mu){
    for (i in 1: nrow(offspring)){
      chromosome <-  offspring[i, ]
      #' generate associated uniform random variable for each locus
      mutationLocus <-  runif(length(chromosome),0,1)
      #' mutation occurs if r.v. < mutationProbability
      #' find the location of mutation
      mutationOccur <- (mutationLocus < mu)
      #return the final result
      offspring[i, ] <- (mutationOccur + chromosome) %% 2
    }
    return(offspring)
  }

  #' Generation Gap
  offspring <- mutation(crossover(candidate,c, parent.pairs, crossover_points), mu)
  if (Gap == 1){
    return(offspring) #return
  }
  else{
    num_replace= floor(P * Gap)
    # assume each time P/2 mother and P/2 father produce P babies
    # num_replace of parents will be replaced by random generated babies

    # index of the replaced parents
    replaced_index= sort(fitness_values, index.return= TRUE)$ix[1:num_replace]
    selected_babies= sample(nrow(offspring), size= num_replace, replace = FALSE)
    candidate[replaced_index,] <- offspring[selected_babies,]
    return(candidate) #return
  }
}

get_model <- function(candidate, method, X, ...){
  #' @title get_model
  #' @description This function returns the parameter of the model once we fit method on candidate
  #' @param candidate (binary vector length c): on or off for each columns of X
  #'     method: method for fitting
  #' @param X (matrix n x (c+1)): data (n x c) and the last column is the value of y.
  #' @return lm/glm object : the model selected after GA.
  best <- candidate[which.min(test_fitness_value),]
  ynam <- colnames(X)[ncol(X)]
  if (sum(best)==0){
    fmla <- as.formula(paste(ynam, " ~ 1"))
    return(method(fmla, data = X,...))
  }else{
    xnam <- colnames(test_data)[which(as.logical(best))]
    fmla <- as.formula(paste( ynam, " ~ ", paste(xnam, collapse= "+")))
    return(method(fmla, data = X,...))
  }
}
