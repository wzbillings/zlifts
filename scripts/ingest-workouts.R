usage <- function() {
  paste(
    "Usage:",
    "  Rscript scripts/ingest-workouts.R --check [splits.csv ...]",
    "  Rscript scripts/ingest-workouts.R --dry-run [splits.csv ...]",
    "  Rscript scripts/ingest-workouts.R --write [splits.csv ...]",
    "",
    "When no CSV paths are provided, the script scans data/raw/workouts/*.csv.",
    sep = "\n"
  )
}

script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0L) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE))
  }

  frame_path <- sys.frame(1)$ofile
  if (is.character(frame_path) && length(frame_path) == 1L) {
    return(normalizePath(frame_path, mustWork = TRUE))
  }

  stop("Cannot determine ingest-workouts.R script path.", call. = FALSE)
}

parse_ingest_args <- function(args) {
  modes <- c("--check", "--dry-run", "--write")
  selected_modes <- args[args %in% modes]

  if (length(selected_modes) != 1L) {
    stop(usage(), call. = FALSE)
  }

  unknown_flags <- args[grepl("^--", args) & !args %in% modes]
  if (length(unknown_flags) > 0) {
    stop(
      paste("Unknown option(s):", paste(unknown_flags, collapse = ", "), "\n", usage()),
      call. = FALSE
    )
  }

  list(
    write = identical(selected_modes, "--write"),
    paths = args[!args %in% modes]
  )
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  parsed_args <- parse_ingest_args(args)
  repo_root <- normalizePath(file.path(dirname(script_path()), ".."), mustWork = TRUE)

  source(file.path(repo_root, "scripts", "source-analysis.R"))
  source_zlifts(repo_root)

  paths <- parsed_args$paths
  if (length(paths) == 0L) {
    paths <- NULL
  }

  report <- ingest_garmin_splits(
    paths = paths,
    lifting_sets_path = file.path(repo_root, "data", "processed", "lifting_sets.csv"),
    exercise_mapping_path = file.path(repo_root, "data", "processed", "exercise_mapping.csv"),
    raw_dir = file.path(repo_root, "data", "raw", "workouts"),
    write = parsed_args$write
  )

  print(report)

  if (any(report$status == "failed")) {
    quit(status = 1L)
  }

  invisible(report)
}

if (sys.nframe() == 0L) {
  main()
}
