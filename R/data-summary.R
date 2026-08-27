#' Summarize lifting sets by exact exercise and workout
#'
#' Summaries preserve exact Garmin exercise names. Movement groups are retained
#' for organization, but different exercise variants are not merged.
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#'
#' @return A tibble with one row per `activity_id` x `date` x `exercise`.
#' @export
summarize_exercises <- function(sets) {
  check_required_columns(sets)

  dplyr::mutate(sets, calculated_volume_lb = set_volume(sets)) |>
    dplyr::group_by(.data$activity_id, .data$date, .data$exercise) |>
    dplyr::summarise(
      day = dplyr::first(.data$day),
      workout_name = first_or_na(.data$workout_name),
      movement_group = first_or_na(.data$movement_group),
      sets = dplyr::n(),
      total_reps = as.integer(sum_or_na(.data$reps)),
      total_volume_lb = sum_or_na(.data$calculated_volume_lb),
      max_weight_lb = max_or_na(.data$weight_lb),
      mean_weight_lb = mean_or_na(.data$weight_lb),
      max_set_volume_lb = max_or_na(.data$calculated_volume_lb),
      .groups = "drop"
    ) |>
    dplyr::select(dplyr::all_of(c(
      "activity_id", "day", "date", "workout_name", "exercise",
      "movement_group", "sets", "total_reps", "total_volume_lb",
      "max_weight_lb", "mean_weight_lb", "max_set_volume_lb"
    ))) |>
    dplyr::arrange(.data$date, .data$activity_id, .data$exercise)
}

#' Summarize lifting sets by workout session
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#'
#' @return A tibble with one row per workout activity.
#' @export
summarize_sessions <- function(sets) {
  check_required_columns(sets)

  dplyr::mutate(sets, calculated_volume_lb = set_volume(sets)) |>
    dplyr::group_by(.data$activity_id, .data$date) |>
    dplyr::summarise(
      day = dplyr::first(.data$day),
      workout_name = first_or_na(.data$workout_name),
      total_sets = dplyr::n(),
      total_reps = as.integer(sum_or_na(.data$reps)),
      total_volume_lb = sum_or_na(.data$calculated_volume_lb),
      exercises = dplyr::n_distinct(.data$exercise),
      .groups = "drop"
    ) |>
    dplyr::select(dplyr::all_of(c(
      "activity_id", "day", "date", "workout_name", "total_sets",
      "total_reps", "total_volume_lb", "exercises"
    ))) |>
    dplyr::arrange(.data$date, .data$activity_id)
}

#' Summarize lifting sets by movement group and workout
#'
#' Movement groups are meant for organization and coverage. This summary does
#' not make exercise variants mechanically equivalent.
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#'
#' @return A tibble with one row per `activity_id` x `date` x `movement_group`.
#' @export
summarize_movement_groups <- function(sets) {
  check_required_columns(sets)

  dplyr::mutate(sets, calculated_volume_lb = set_volume(sets)) |>
    dplyr::group_by(.data$activity_id, .data$date, .data$movement_group) |>
    dplyr::summarise(
      day = dplyr::first(.data$day),
      workout_name = first_or_na(.data$workout_name),
      sets = dplyr::n(),
      total_reps = as.integer(sum_or_na(.data$reps)),
      total_volume_lb = sum_or_na(.data$calculated_volume_lb),
      max_recorded_weight_lb = max_or_na(.data$weight_lb),
      exercise_variants = dplyr::n_distinct(.data$exercise),
      .groups = "drop"
    ) |>
    dplyr::select(dplyr::all_of(c(
      "activity_id", "day", "date", "workout_name", "movement_group",
      "sets", "total_reps", "total_volume_lb", "max_recorded_weight_lb",
      "exercise_variants"
    ))) |>
    dplyr::arrange(.data$date, .data$activity_id, .data$movement_group)
}

