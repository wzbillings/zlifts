repo_file_candidates <- function(...) {
  relative_path <- file.path(...)
  c(
    relative_path,
    file.path("..", "..", relative_path),
    file.path("..", "..", "..", relative_path)
  )
}

local_repo_file_path <- function(...) {
  candidates <- repo_file_candidates(...)
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0) {
    return(NA_character_)
  }
  normalizePath(existing[[1]], mustWork = TRUE)
}

local_processed_file_path <- function(file) {
  local_repo_file_path("data", "processed", file)
}

processed_file_path <- function(file) {
  path <- local_processed_file_path(file)
  if (is.na(path)) {
    stop("Cannot find processed data file: ", file, call. = FALSE)
  }
  path
}

local_processed_lifting_sets_path <- function() {
  local_processed_file_path("lifting_sets.csv")
}

skip_if_no_processed_data <- function() {
  testthat::skip_if(
    is.na(local_processed_lifting_sets_path()),
    "Processed data are stored in the repository data/ directory."
  )
}

processed_lifting_sets_path <- function() {
  processed_file_path("lifting_sets.csv")
}

processed_workouts_path <- function() {
  processed_file_path("workouts.csv")
}

processed_exercise_mapping_path <- function() {
  processed_file_path("exercise_mapping.csv")
}

read_processed_lifting_sets <- function(apply_mapping = TRUE) {
  read_lifting_sets(
    processed_lifting_sets_path(),
    apply_mapping = apply_mapping,
    exercise_mapping = processed_exercise_mapping_path()
  )
}

local_processed_fixture_file_path <- function(file) {
  local_repo_file_path("tests", "fixtures", "processed", file)
}

processed_fixture_file_path <- function(file) {
  path <- local_processed_fixture_file_path(file)
  if (is.na(path)) {
    stop("Cannot find processed fixture file: ", file, call. = FALSE)
  }
  path
}

fixture_lifting_sets_path <- function() {
  processed_fixture_file_path("lifting_sets.csv")
}

fixture_workouts_path <- function() {
  processed_fixture_file_path("workouts.csv")
}

fixture_exercise_mapping_path <- function() {
  processed_fixture_file_path("exercise_mapping.csv")
}

read_fixture_lifting_sets <- function(apply_mapping = TRUE) {
  read_lifting_sets(
    fixture_lifting_sets_path(),
    apply_mapping = apply_mapping,
    exercise_mapping = fixture_exercise_mapping_path()
  )
}

read_fixture_workouts <- function() {
  read_workouts(fixture_workouts_path())
}

local_seed_lifting_sets_path <- function() {
  local_processed_lifting_sets_path()
}

skip_if_no_seed_data <- function() {
  skip_if_no_processed_data()
}

seed_lifting_sets_path <- function() {
  processed_lifting_sets_path()
}
