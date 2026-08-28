# Locate the project root from a starting path by checking stable repository markers.
find_project_root <- function(start = getwd()) {
  path <- normalizePath(start, mustWork = TRUE)
  if (!dir.exists(path)) {
    path <- dirname(path)
  }

  markers <- c(
    file.path("dashboard", "_quarto.yml"),
    file.path("data", "processed", "lifting_sets.csv"),
    file.path("R", "utils.R")
  )

  repeat {
    if (all(file.exists(file.path(path, markers)))) {
      return(path)
    }

    parent <- dirname(path)
    if (identical(parent, path)) {
      stop("Could not find zlifts project root from ", start, call. = FALSE)
    }
    path <- parent
  }
}

# Source project-local analysis modules in dependency order.
source_zlifts <- function(repo_root = find_project_root(), envir = parent.frame()) {
  repo_root <- normalizePath(repo_root, mustWork = TRUE)
  analysis_files <- file.path(repo_root, c(
    "R/utils.R",
    "R/exercise-mapping.R",
    "R/data-load.R",
    "R/data-validation.R",
    "R/data-summary.R",
    "R/plot-utils.R",
    "R/plot-session.R",
    "R/plot-volume.R",
    "R/plot-max-weight.R",
    "R/plot-sets.R"
  ))

  missing_files <- analysis_files[!file.exists(analysis_files)]
  if (length(missing_files) > 0) {
    stop(
      "Cannot source zlifts analysis file(s): ",
      paste(missing_files, collapse = ", "),
      call. = FALSE
    )
  }

  for (file in analysis_files) {
    source(file, local = envir)
  }

  invisible(envir)
}
