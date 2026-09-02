#' Build the public row payload used by static dashboard filters
#'
#' The dashboard is static on GitHub Pages, so filter state is handled in the
#' browser. This helper keeps the embedded data limited to committed processed
#' set fields and display labels.
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#'
#' @return A list with render metadata and one processed row per lifting set.
dashboard_filter_payload <- function(sets) {
  check_required_columns(sets)

  rows <- sets |>
    dplyr::mutate(
      date = format(as.Date(.data$date), "%Y-%m-%d"),
      activity_id = as.character(.data$activity_id),
      exercise_label = exercise_display_name(.data[['exercise']], .data[['equipment_type']], .data[['exercise_variant']]),
      equipment_label = format_equipment_type(.data$equipment_type),
      calculated_volume_lb = set_volume(sets),
      volume_lb = .data$calculated_volume_lb
    ) |>
    dplyr::select(dplyr::all_of(c(
      "activity_id", "day", "date", "date_source", "workout_name",
      'set_number', 'exercise_raw', 'exercise', 'exercise_variant', 'movement_group',
      'equipment_type', 'equipment_label', 'exercise_label', 'set_type',
      "time_raw", "time_seconds", "rest_raw", "rest_seconds", "reps",
      "weight_lb", "garmin_volume_lb", "volume_lb", "volume_matches_garmin"
    ))) |>
    as.data.frame(stringsAsFactors = FALSE)

  list(
    generated_at = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    rows = rows
  )
}
