required_workout_columns <- function() {
  c("activity_id", "day", "date", "date_source", "workout_name")
}

check_workout_columns <- function(workouts) {
  missing <- setdiff(required_workout_columns(), names(workouts))
  if (length(missing) > 0) {
    rlang::abort(
      c(
        "Missing required column(s) in workout metadata.",
        x = paste("Missing required column(s):", paste(missing, collapse = ", "))
      ),
      class = "zlifts_missing_workout_columns"
    )
  }
  invisible(workouts)
}

default_workouts_path <- function(path = NULL, lifting_sets_path = NULL) {
  if (!is.null(path)) {
    return(path)
  }

  if (!is.null(lifting_sets_path)) {
    return(file.path(dirname(lifting_sets_path), "workouts.csv"))
  }

  if (exists("find_project_root", mode = "function")) {
    return(file.path(find_project_root(), "data", "processed", "workouts.csv"))
  }

  file.path("data", "processed", "workouts.csv")
}

read_workouts <- function(path = file.path("data", "processed", "workouts.csv")) {
  if (!file.exists(path)) {
    rlang::abort(
      c("Cannot find workout metadata.", x = paste("Path does not exist:", path)),
      class = "zlifts_missing_file"
    )
  }

  workouts <- readr::read_csv(
    path,
    col_types = readr::cols(
      activity_id = readr::col_character(),
      day = readr::col_integer(),
      date = readr::col_date(),
      date_source = readr::col_character(),
      workout_name = readr::col_character()
    ),
    show_col_types = FALSE
  )

  check_workout_columns(workouts)
  dplyr::mutate(
    dplyr::select(workouts, dplyr::all_of(required_workout_columns())),
    date = as.Date(.data$date)
  )
}

derive_workouts_from_sets <- function(sets) {
  check_required_columns(sets)

  sets |>
    dplyr::distinct(
      .data$activity_id,
      .data$day,
      .data$date,
      .data$date_source,
      .data$workout_name
    ) |>
    dplyr::arrange(.data$day, .data$date, .data$activity_id) |>
    dplyr::select(dplyr::all_of(required_workout_columns()))
}

resolve_workouts <- function(workouts = NULL, path = NULL) {
  if (!is.null(workouts)) {
    check_workout_columns(workouts)
    return(dplyr::mutate(
      dplyr::select(workouts, dplyr::all_of(required_workout_columns())),
      date = as.Date(.data$date)
    ))
  }

  if (!is.null(path)) {
    return(read_workouts(path))
  }

  NULL
}
