#' @title Trinity VSA - Vector Symbolic Architecture
#' @description Balanced ternary arithmetic for hyperdimensional computing
#' @name TrinityVSA
#' @docType package
NULL

#' Create zero trit vector
#' @param dim Dimension of vector
#' @return Integer vector of zeros
#' @export
trit_zeros <- function(dim) {
  as.integer(rep(0L, dim))
}

#' Create random trit vector
#' @param dim Dimension of vector
#' @param seed Random seed (optional)
#' @return Integer vector with values in {-1, 0, 1}
#' @export
trit_random <- function(dim, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  as.integer(sample(c(-1L, 0L, 1L), dim, replace = TRUE))
}

#' Bind two trit vectors
#' @param a First vector
#' @param b Second vector
#' @return Element-wise product
#' @export
trit_bind <- function(a, b) {
  stopifnot(length(a) == length(b))
  as.integer(a * b)
}

#' Unbind (inverse of bind)
#' @param a First vector
#' @param b Second vector
#' @return Unbound vector
#' @export
trit_unbind <- function(a, b) {
  trit_bind(a, b)
}

#' Bundle multiple vectors via majority voting
#' @param vectors List of trit vectors
#' @return Bundled vector
#' @export
trit_bundle <- function(vectors) {
  stopifnot(length(vectors) > 0)
  dim <- length(vectors[[1]])
  result <- integer(dim)
  
  for (i in seq_len(dim)) {
    s <- sum(sapply(vectors, function(v) v[i]))
    result[i] <- if (s > 0) 1L else if (s < 0) -1L else 0L
  }
  result
}

#' Circular permutation
#' @param v Trit vector
#' @param shift Shift amount
#' @return Permuted vector
#' @export
trit_permute <- function(v, shift) {
  dim <- length(v)
  idx <- ((seq_len(dim) - 1 + shift) %% dim) + 1
  v[idx]
}

#' Dot product
#' @param a First vector
#' @param b Second vector
#' @return Dot product
#' @export
trit_dot <- function(a, b) {
  stopifnot(length(a) == length(b))
  sum(as.numeric(a) * as.numeric(b))
}

#' Cosine similarity
#' @param a First vector
#' @param b Second vector
#' @return Similarity in [-1, 1]
#' @export
trit_similarity <- function(a, b) {
  d <- trit_dot(a, b)
  norm_a <- sqrt(trit_dot(a, a))
  norm_b <- sqrt(trit_dot(b, b))
  if (norm_a == 0 || norm_b == 0) return(0)
  d / (norm_a * norm_b)
}

#' Hamming distance
#' @param a First vector
#' @param b Second vector
#' @return Number of differing positions
#' @export
trit_hamming <- function(a, b) {
  stopifnot(length(a) == length(b))
  sum(a != b)
}

#' Number of non-zero elements
#' @param v Trit vector
#' @return Count of non-zeros
#' @export
trit_nnz <- function(v) {
  sum(v != 0)
}

#' Sparsity (fraction of zeros)
#' @param v Trit vector
#' @return Sparsity ratio
#' @export
trit_sparsity <- function(v) {
  1 - trit_nnz(v) / length(v)
}
