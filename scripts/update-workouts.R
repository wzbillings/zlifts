usage <- function() {
  paste(
    "Usage:",
    "  Rscript scripts/update-workouts.R --check [splits.csv ...]",
    "  Rscript scripts/update-workouts.R --write [splits.csv ...]",
    "",
    "When no CSV paths are provided, the importer scans data/raw/workouts/*.csv.",
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

  stop("Cannot determine update-workouts.R script path.", call. = FALSE)
}

parse_update_args <- function(args) {
  modes <- c("--check", "--write")
  unknown_flags <- args[grepl("^--", args) & !args %in% modes]

  if (length(unknown_flags) > 0L) {
    stop(
      paste("Unknown option(s):", paste(unknown_flags, collapse = ", "), "\n", usage()),
      call. = FALSE
    )
  }

  selected_modes <- args[args %in% modes]
  if (length(selected_modes) != 1L) {
    stop(usage(), call. = FALSE)
  }

  list(
    mode = selected_modes[[1]],
    paths = args[!args %in% modes]
  )
}

update_command_plan <- function(mode, paths = character()) {
  commands <- list(
    list("Rscript", c("scripts/ingest-workouts.R", mode, paths), "importer"),
    list("Rscript", c("tests/testthat.R"), "tests"),
    list("quarto", c("render", "dashboard"), "dashboard render")
  )

  if (identical(mode, "--write")) {
    commands <- c(commands, list(list("git", c("status", "--short"), "git status")))
  }

  commands
}

run_update_command <- function(command) {
  executable <- command[[1]]
  arguments <- command[[2]]
  label <- command[[3]]

  message("Running ", label, ": ", paste(c(executable, arguments), collapse = " "))
  status <- tryCatch(
    system2(executable, arguments),
    error = function(error) {
      stop(label, " could not start: ", conditionMessage(error), call. = FALSE)
    }
  )

  if (!identical(status, 0L)) {
    stop(label, " failed with exit status ", status, ". No later commands were run.", call. = FALSE)
  }
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  parsed_args <- parse_update_args(args)
  repo_root <- normalizePath(file.path(dirname(script_path()), ".."), mustWork = TRUE)

  old_working_directory <- getwd()
  on.exit(setwd(old_working_directory), add = TRUE)
  setwd(repo_root)

  for (command in update_command_plan(parsed_args$mode, parsed_args$paths)) {
    run_update_command(command)
  }

  invisible(NULL)
}

if (sys.nframe() == 0L) {
  main()
}
