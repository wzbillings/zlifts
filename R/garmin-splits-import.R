canonical_lifting_set_columns <- function() {
  c(
    "activity_id", "day", "date", "date_source", "workout_name", "set_number",
    "exercise_raw", "exercise", "movement_group", "equipment_type", "set_type",
    "time_raw", "time_seconds", "rest_raw", "rest_seconds", "reps", "weight_lb",
    "garmin_volume_lb", "volume_lb", "volume_matches_garmin"
  )
}

garmin_splits_required_columns <- function() {
  c("Set", "Exercise Name", "Time", "Rest", "Reps", "Weight", "Volume")
}

default_lifting_sets_path <- function(path = NULL) {
  if (!is.null(path)) {
    return(path)
  }

  if (exists("find_project_root", mode = "function")) {
    return(file.path(find_project_root(), "data", "processed", "lifting_sets.csv"))
  }

  file.path("data", "processed", "lifting_sets.csv")
}

default_raw_workouts_path <- function(path = NULL) {
  if (!is.null(path)) {
    return(path)
  }

  if (exists("find_project_root", mode = "function")) {
    return(file.path(find_project_root(), "data", "raw", "workouts"))
  }

  file.path("data", "raw", "workouts")
}

discover_garmin_splits_files <- function(raw_dir = NULL) {
  raw_dir <- default_raw_workouts_path(raw_dir)
  if (!dir.exists(raw_dir)) {
    return(character())
  }

  sort(list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE))
}

parse_garmin_splits_filename <- function(path) {
  file_name <- basename(path)
  match <- regexec(
    "^([0-9]{4}-[0-9]{2}-[0-9]{2})-garmin-splits-([0-9]+)\\.csv$",
    file_name
  )
  parts <- regmatches(file_name, match)[[1]]

  if (length(parts) != 3) {
    rlang::abort(
      c(
        "Garmin Splits CSV filename is missing workout metadata.",
        x = paste("Expected filename convention:", "YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv"),
        i = paste("Received:", file_name)
      ),
      class = "zlifts_bad_garmin_splits_filename"
    )
  }

  workout_date <- as.Date(parts[[2]])
  if (is.na(workout_date)) {
    rlang::abort(
      c(
        "Garmin Splits CSV filename has an invalid workout date.",
        x = paste("Expected filename convention:", "YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv"),
        i = paste("Received:", file_name)
      ),
      class = "zlifts_bad_garmin_splits_filename"
    )
  }

  activity_id <- parts[[3]]
  list(
    activity_id = activity_id,
    date = workout_date,
    date_source = "raw filename",
    workout_name = paste0("Garmin Strength ", format(workout_date, "%Y-%m-%d"), " (", activity_id, ")")
  )
}

parse_garmin_numeric_column <- function(x, column) {
  values <- trimws(as.character(x))
  missing <- is.na(x) | toupper(values) %in% c("", "NA", "N/A", "--")
  parsed <- readr::parse_number(
    values,
    na = c("", "NA", "N/A", "--"),
    locale = readr::locale(grouping_mark = ",")
  )
  bad_values <- !missing & is.na(parsed)

  if (any(bad_values)) {
    rlang::abort(
      c(
        "Cannot parse numeric Garmin Splits value.",
        x = paste0("Column ", column, " has invalid value(s): ", paste(unique(values[bad_values]), collapse = ", "))
      ),
      class = "zlifts_bad_garmin_splits_value"
    )
  }

  parsed
}

parse_garmin_integer_column <- function(x, column) {
  parsed <- parse_garmin_numeric_column(x, column)
  fractional <- !is.na(parsed) & parsed != floor(parsed)

  if (any(fractional)) {
    rlang::abort(
      c(
        "Garmin Splits value must be a whole number.",
        x = paste0("Column ", column, " has non-whole value(s): ", paste(unique(parsed[fractional]), collapse = ", "))
      ),
      class = "zlifts_bad_garmin_splits_value"
    )
  }

  as.integer(parsed)
}

parse_garmin_duration_seconds <- function(x, column = "duration") {
  values <- trimws(as.character(x))
  missing <- is.na(x) | toupper(values) %in% c("", "NA", "N/A", "--")
  out <- rep(NA_real_, length(values))

  for (index in which(!missing)) {
    value <- values[[index]]
    parts <- strsplit(value, ":", fixed = TRUE)[[1]]

    if (!length(parts) %in% c(2L, 3L)) {
      rlang::abort(
        c(
          "Cannot parse Garmin Splits duration.",
          x = paste0("Column ", column, " expects M:SS or H:MM:SS values."),
          i = paste("Invalid value:", value)
        ),
        class = "zlifts_bad_garmin_splits_duration"
      )
    }

    numeric_parts <- suppressWarnings(as.numeric(parts))
    if (any(is.na(numeric_parts))) {
      rlang::abort(
        c(
          "Cannot parse Garmin Splits duration.",
          x = paste0("Column ", column, " expects M:SS or H:MM:SS values."),
          i = paste("Invalid value:", value)
        ),
        class = "zlifts_bad_garmin_splits_duration"
      )
    }

    if (length(numeric_parts) == 2L) {
      out[[index]] <- numeric_parts[[1]] * 60 + numeric_parts[[2]]
    } else {
      out[[index]] <- numeric_parts[[1]] * 3600 + numeric_parts[[2]] * 60 + numeric_parts[[3]]
    }
  }

  out
}

read_garmin_splits_source <- function(path) {
  if (!file.exists(path)) {
    rlang::abort(
      c(
        "Cannot find Garmin Splits CSV.",
        x = paste("Path does not exist:", path)
      ),
      class = "zlifts_missing_file"
    )
  }

  source <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    name_repair = "minimal",
    show_col_types = FALSE
  )
  names(source) <- trimws(names(source))

  duplicate_names <- duplicated(names(source)) | duplicated(names(source), fromLast = TRUE)
  if (any(duplicate_names)) {
    rlang::abort(
      c(
        "Garmin Splits CSV has duplicate column names after trimming whitespace.",
        x = paste("Duplicate column name(s):", paste(unique(names(source)[duplicate_names]), collapse = ", "))
      ),
      class = "zlifts_bad_garmin_splits_columns"
    )
  }

  missing <- setdiff(garmin_splits_required_columns(), names(source))
  if (length(missing) > 0) {
    rlang::abort(
      c(
        "Missing required Garmin Splits column(s).",
        x = paste("Missing required Garmin Splits column(s):", paste(missing, collapse = ", "))
      ),
      class = "zlifts_missing_columns"
    )
  }

  source
}

resolve_import_mapping_input <- function(exercise_mapping = NULL, exercise_mapping_path = NULL) {
  if (!is.null(exercise_mapping)) {
    return(exercise_mapping)
  }
  if (!is.null(exercise_mapping_path)) {
    return(exercise_mapping_path)
  }
  NULL
}

resolve_import_mapping_path_label <- function(exercise_mapping = NULL, exercise_mapping_path = NULL) {
  if (!is.null(exercise_mapping_path)) {
    return(exercise_mapping_path)
  }
  if (is.character(exercise_mapping) && length(exercise_mapping) == 1L) {
    return(exercise_mapping)
  }
  default_exercise_mapping_path()
}

parse_garmin_splits_csv <- function(path,
                                    exercise_mapping = NULL,
                                    exercise_mapping_path = NULL,
                                    day,
                                    tolerance = 1e-8) {
  if (missing(day) || length(day) != 1L || is.na(day) || day <= 0 || day != floor(day)) {
    rlang::abort(
      "`day` must be a single positive whole number for append-only ingestion.",
      class = "zlifts_bad_garmin_splits_day"
    )
  }

  metadata <- parse_garmin_splits_filename(path)
  source <- read_garmin_splits_source(path)

  reps <- parse_garmin_integer_column(source[["Reps"]], "Reps")
  weight_lb <- parse_garmin_numeric_column(source[["Weight"]], "Weight")
  garmin_volume_lb <- parse_garmin_numeric_column(source[["Volume"]], "Volume")
  volume_lb <- reps * weight_lb
  comparable_garmin_volume <- !is.na(garmin_volume_lb) & !is.na(volume_lb)
  volume_matches_garmin <- rep(NA, length(volume_lb))
  volume_matches_garmin[comparable_garmin_volume] <-
    abs(garmin_volume_lb[comparable_garmin_volume] - volume_lb[comparable_garmin_volume]) <= tolerance

  rows <- tibble::tibble(
    activity_id = metadata$activity_id,
    day = as.integer(day),
    date = metadata$date,
    date_source = metadata$date_source,
    workout_name = metadata$workout_name,
    set_number = parse_garmin_integer_column(source[["Set"]], "Set"),
    exercise_raw = as.character(source[["Exercise Name"]]),
    exercise = as.character(source[["Exercise Name"]]),
    movement_group = as.character(source[["Exercise Name"]]),
    equipment_type = NA_character_,
    set_type = NA_character_,
    time_raw = as.character(source[["Time"]]),
    time_seconds = parse_garmin_duration_seconds(source[["Time"]], "Time"),
    rest_raw = as.character(source[["Rest"]]),
    rest_seconds = parse_garmin_duration_seconds(source[["Rest"]], "Rest"),
    reps = reps,
    weight_lb = weight_lb,
    garmin_volume_lb = garmin_volume_lb,
    volume_lb = volume_lb,
    volume_matches_garmin = volume_matches_garmin
  )

  mapping_input <- resolve_import_mapping_input(exercise_mapping, exercise_mapping_path)
  mapping_path_label <- resolve_import_mapping_path_label(exercise_mapping, exercise_mapping_path)

  mapped_rows <- tryCatch(
    apply_exercise_mapping(rows, mapping_input),
    zlifts_unmapped_exercises = function(error) {
      unmapped <- unmapped_exercise_names(rows, mapping_input)
      abort_unmapped_exercises(unmapped, mapping_path_label)
    }
  )

  dplyr::select(mapped_rows, dplyr::all_of(canonical_lifting_set_columns()))
}

empty_garmin_ingest_report <- function() {
  report <- tibble::tibble(
    file = character(),
    activity_id = character(),
    status = character(),
    message = character(),
    added_rows = integer(),
    skipped_rows = integer(),
    failed_rows = integer()
  )
  class(report) <- c("zlifts_garmin_ingest_report", class(report))
  report
}

garmin_ingest_report_row <- function(file,
                                     activity_id = NA_character_,
                                     status,
                                     message,
                                     added_rows = 0L,
                                     skipped_rows = 0L,
                                     failed_rows = 0L) {
  tibble::tibble(
    file = as.character(file),
    activity_id = as.character(activity_id),
    status = as.character(status),
    message = as.character(message),
    added_rows = as.integer(added_rows),
    skipped_rows = as.integer(skipped_rows),
    failed_rows = as.integer(failed_rows)
  )
}

class_garmin_ingest_report <- function(report) {
  class(report) <- c("zlifts_garmin_ingest_report", class(report))
  report
}


format_garmin_ingest_error <- function(error) {
  if (inherits(error, "rlang_error")) {
    return(rlang::cnd_message(error))
  }

  conditionMessage(error)
}

existing_activity_counts <- function(sets) {
  counts <- table(sets$activity_id, useNA = "no")
  stats::setNames(as.integer(counts), names(counts))
}

next_append_day <- function(existing_sets) {
  if (nrow(existing_sets) == 0 || all(is.na(existing_sets$day))) {
    return(1L)
  }
  as.integer(max(existing_sets$day, na.rm = TRUE) + 1L)
}

summarize_failed_validation <- function(validation) {
  failures <- validation[validation$status == "fail", , drop = FALSE]
  paste(failures$message, collapse = "; ")
}

ingest_garmin_splits <- function(paths = NULL,
                                 raw_dir = NULL,
                                 lifting_sets_path = NULL,
                                 exercise_mapping = NULL,
                                 exercise_mapping_path = NULL,
                                 write = FALSE) {
  lifting_sets_path <- default_lifting_sets_path(lifting_sets_path)
  if (is.null(exercise_mapping_path)) {
    exercise_mapping_path <- file.path(dirname(lifting_sets_path), "exercise_mapping.csv")
  }
  mapping_input <- resolve_import_mapping_input(exercise_mapping, exercise_mapping_path)

  if (is.null(paths)) {
    paths <- discover_garmin_splits_files(raw_dir)
  } else {
    paths <- sort(as.character(paths))
  }

  if (length(paths) == 0) {
    return(empty_garmin_ingest_report())
  }

  existing_sets <- read_lifting_sets(lifting_sets_path, apply_mapping = FALSE)
  current_counts <- existing_activity_counts(existing_sets)
  current_activity_ids <- names(current_counts)
  existing_activity_ids <- current_activity_ids
  next_day <- next_append_day(existing_sets)
  reports <- list()
  parsed_rows <- list()
  parsed_report_indexes <- integer()

  for (path in paths) {
    metadata_result <- tryCatch(
      list(value = parse_garmin_splits_filename(path), error = NULL),
      error = function(error) list(value = NULL, error = error)
    )

    if (!is.null(metadata_result$error)) {
      reports[[length(reports) + 1L]] <- garmin_ingest_report_row(
        file = path,
        status = "failed",
        message = format_garmin_ingest_error(metadata_result$error),
        failed_rows = 0L
      )
      next
    }

    activity_id <- metadata_result$value$activity_id
    if (activity_id %in% current_activity_ids) {
      skipped_rows <- unname(current_counts[[activity_id]])
      if (activity_id %in% existing_activity_ids) {
        skip_message <- paste0("Activity id ", activity_id, " already exists in ", lifting_sets_path, "; skipped.")
      } else {
        skip_message <- paste0("Activity id ", activity_id, " was already parsed earlier in this run; skipped.")
      }
      reports[[length(reports) + 1L]] <- garmin_ingest_report_row(
        file = path,
        activity_id = activity_id,
        status = "skipped",
        message = skip_message,
        skipped_rows = skipped_rows
      )
      next
    }

    parsed_result <- tryCatch(
      list(
        value = parse_garmin_splits_csv(
          path,
          exercise_mapping = exercise_mapping,
          exercise_mapping_path = exercise_mapping_path,
          day = next_day
        ),
        error = NULL
      ),
      error = function(error) list(value = NULL, error = error)
    )

    if (!is.null(parsed_result$error)) {
      reports[[length(reports) + 1L]] <- garmin_ingest_report_row(
        file = path,
        activity_id = activity_id,
        status = "failed",
        message = format_garmin_ingest_error(parsed_result$error),
        failed_rows = 0L
      )
      next
    }

    rows <- parsed_result$value
    current_activity_ids <- c(current_activity_ids, activity_id)
    current_counts[[activity_id]] <- nrow(rows)
    next_day <- next_day + 1L
    parsed_rows[[length(parsed_rows) + 1L]] <- rows
    reports[[length(reports) + 1L]] <- garmin_ingest_report_row(
      file = path,
      activity_id = activity_id,
      status = "would_add",
      message = paste0("Parsed ", nrow(rows), " set row(s)."),
      added_rows = nrow(rows)
    )
    parsed_report_indexes <- c(parsed_report_indexes, length(reports))
  }

  report <- dplyr::bind_rows(reports)
  new_rows <- dplyr::bind_rows(parsed_rows)
  has_failed_files <- any(report$status == "failed")

  if (nrow(new_rows) > 0 && !has_failed_files) {
    combined_sets <- dplyr::bind_rows(existing_sets, new_rows)
    validation <- validate_lifting_data(combined_sets, exercise_mapping = mapping_input)
    failed_validation <- validation[validation$status == "fail", , drop = FALSE]

    if (nrow(failed_validation) > 0) {
      validation_message <- paste0(
        "Combined lifting data failed validation: ",
        summarize_failed_validation(validation)
      )
      report$status[parsed_report_indexes] <- "failed"
      report$message[parsed_report_indexes] <- validation_message
      report$failed_rows[parsed_report_indexes] <- report$added_rows[parsed_report_indexes]
      report$added_rows[parsed_report_indexes] <- 0L
    } else if (isTRUE(write)) {
      readr::write_csv(
        new_rows,
        lifting_sets_path,
        append = TRUE,
        col_names = FALSE,
        na = ""
      )
      report$status[parsed_report_indexes] <- "added"
      report$message[parsed_report_indexes] <- paste0("Added ", report$added_rows[parsed_report_indexes], " set row(s).")
    }
  } else if (isTRUE(write) && nrow(new_rows) > 0 && has_failed_files) {
    report$status[parsed_report_indexes] <- "failed"
    report$message[parsed_report_indexes] <- "Parsed successfully, but no rows were written because one or more files failed."
    report$failed_rows[parsed_report_indexes] <- report$added_rows[parsed_report_indexes]
    report$added_rows[parsed_report_indexes] <- 0L
  }

  class_garmin_ingest_report(report)
}

print.zlifts_garmin_ingest_report <- function(x, ...) {
  if (nrow(x) == 0) {
    cat("No Garmin Splits CSV files found.\n")
    return(invisible(x))
  }

  counts <- table(x$status)
  summary <- paste(paste(names(counts), as.integer(counts), sep = ": "), collapse = ", ")
  cat("Garmin Splits ingestion report (", summary, ")\n", sep = "")
  NextMethod()
}
