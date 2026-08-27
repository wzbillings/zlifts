#' Read canonical Garmin lifting set data
#'
#' `read_lifting_sets()` reads the normalized set-level CSV that acts as the
#' source of truth for this project. It parses workout dates, keeps activity IDs
#' as character values, checks the expected columns, and returns a tibble.
#'
#' @param path Path to the canonical `lifting_sets.csv` file.
#'
#' @return A tibble with one row per recorded lifting set.
#' @export
read_lifting_sets <- function(path = file.path("data", "processed", "lifting_sets.csv")) {
  if (!file.exists(path)) {
    rlang::abort(
      c("Cannot find lifting set data.", x = paste("Path does not exist:", path)),
      class = "zlifts_missing_file"
    )
  }

  sets <- readr::read_csv(
    path,
    col_types = readr::cols(
      activity_id = readr::col_character(),
      day = readr::col_integer(),
      date = readr::col_date(),
      date_source = readr::col_character(),
      workout_name = readr::col_character(),
      set_number = readr::col_integer(),
      exercise_raw = readr::col_character(),
      exercise = readr::col_character(),
      movement_group = readr::col_character(),
      set_type = readr::col_character(),
      time_raw = readr::col_character(),
      time_seconds = readr::col_double(),
      rest_raw = readr::col_character(),
      rest_seconds = readr::col_double(),
      reps = readr::col_integer(),
      weight_lb = readr::col_double(),
      garmin_volume_lb = readr::col_double(),
      volume_lb = readr::col_double(),
      volume_matches_garmin = readr::col_character()
    ),
    show_col_types = FALSE
  )

  check_required_columns(sets)

  dplyr::mutate(
    sets,
    date = as.Date(.data$date),
    volume_matches_garmin = parse_logical_text(.data$volume_matches_garmin)
  )
}
