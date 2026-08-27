local_seed_lifting_sets_path <- function() {
  candidates <- c(
    file.path("data", "processed", "lifting_sets.csv"),
    file.path("..", "..", "data", "processed", "lifting_sets.csv"),
    file.path("..", "..", "..", "data", "processed", "lifting_sets.csv")
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0) {
    return(NA_character_)
  }
  normalizePath(existing[[1]], mustWork = TRUE)
}

skip_if_no_seed_data <- function() {
  testthat::skip_if(
    is.na(local_seed_lifting_sets_path()),
    "Seed data are stored in the repository data/ directory."
  )
}

seed_lifting_sets_path <- function() {
  path <- local_seed_lifting_sets_path()
  if (is.na(path)) {
    stop("Cannot find seed lifting_sets.csv", call. = FALSE)
  }
  path
}
