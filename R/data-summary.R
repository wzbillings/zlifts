#' Summarize lifting sets by exact exercise and workout
#'
#' Summaries preserve exact Garmin exercise names. Movement groups are retained
#' for organization, but different exercise variants are not merged.
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#'
#' @return A tibble with one row per `activity_id` x `date` x `exercise`.
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

summarize_session_progress <- function(sets) {
  check_required_columns(sets)
  session_summary <- summarize_sessions(sets)

  if (nrow(session_summary) == 0) {
    return(tibble::tibble(
      total_workouts = 0L,
      total_sets = 0L,
      total_reps = 0L,
      cumulative_volume_lb = 0,
      latest_workout_date = as.Date(NA),
      latest_workout_name = NA_character_,
      latest_workout_total_volume_lb = NA_real_
    ))
  }

  latest_session <- session_summary |>
    dplyr::arrange(.data$date, .data$activity_id) |>
    dplyr::slice_tail(n = 1)

  tibble::tibble(
    total_workouts = as.integer(nrow(session_summary)),
    total_sets = as.integer(sum(session_summary$total_sets, na.rm = TRUE)),
    total_reps = as.integer(sum(session_summary$total_reps, na.rm = TRUE)),
    cumulative_volume_lb = sum(session_summary$total_volume_lb, na.rm = TRUE),
    latest_workout_date = latest_session$date[[1]],
    latest_workout_name = latest_session$workout_name[[1]],
    latest_workout_total_volume_lb = latest_session$total_volume_lb[[1]]
  )
}

summarize_exercise_progress <- function(sets, min_observations = 2L) {
  check_required_columns(sets)

  if (length(min_observations) != 1 || is.na(min_observations) || min_observations < 1) {
    rlang::abort(
      "`min_observations` must be a single positive number.",
      class = "zlifts_bad_min_observations"
    )
  }

  exercise_summary <- summarize_exercises(sets) |>
    dplyr::arrange(.data$date, .data$activity_id, .data$exercise)

  if (nrow(exercise_summary) == 0) {
    return(empty_exercise_progress())
  }

  first_observations <- exercise_summary |>
    dplyr::group_by(.data$exercise) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() |>
    dplyr::transmute(
      exercise = .data$exercise,
      first_workout_date = .data$date,
      first_recorded_max_weight_lb = .data$max_weight_lb
    )

  latest_observations <- exercise_summary |>
    dplyr::group_by(.data$exercise) |>
    dplyr::slice_tail(n = 1) |>
    dplyr::ungroup() |>
    dplyr::transmute(
      exercise = .data$exercise,
      latest_workout_date = .data$date,
      latest_recorded_max_weight_lb = .data$max_weight_lb,
      latest_exercise_volume_lb = .data$total_volume_lb
    )

  exercise_summary |>
    dplyr::group_by(.data$exercise) |>
    dplyr::summarise(
      workout_count = as.integer(dplyr::n_distinct(.data$activity_id)),
      all_time_max_weight_lb = max_or_na(.data$max_weight_lb),
      all_time_highest_exercise_volume_lb = max_or_na(.data$total_volume_lb),
      .groups = "drop"
    ) |>
    dplyr::left_join(first_observations, by = "exercise") |>
    dplyr::left_join(latest_observations, by = "exercise") |>
    dplyr::mutate(
      has_repeated_observations = .data$workout_count >= min_observations,
      change_from_first_recorded_max_weight_lb = dplyr::if_else(
        .data$has_repeated_observations &
          !is.na(.data$latest_recorded_max_weight_lb) &
          !is.na(.data$first_recorded_max_weight_lb),
        .data$latest_recorded_max_weight_lb - .data$first_recorded_max_weight_lb,
        NA_real_
      ),
      progress_note = progress_note(
        .data$has_repeated_observations,
        .data$change_from_first_recorded_max_weight_lb
      )
    ) |>
    dplyr::select(dplyr::all_of(c(
      "exercise", "workout_count", "first_workout_date", "latest_workout_date",
      "latest_recorded_max_weight_lb", "all_time_max_weight_lb",
      "change_from_first_recorded_max_weight_lb", "latest_exercise_volume_lb",
      "all_time_highest_exercise_volume_lb", "has_repeated_observations",
      "progress_note"
    ))) |>
    dplyr::arrange(
      dplyr::desc(.data$has_repeated_observations),
      dplyr::desc(.data$all_time_max_weight_lb),
      .data$exercise
    )
}

empty_exercise_progress <- function() {
  tibble::tibble(
    exercise = character(),
    workout_count = integer(),
    first_workout_date = as.Date(character()),
    latest_workout_date = as.Date(character()),
    latest_recorded_max_weight_lb = numeric(),
    all_time_max_weight_lb = numeric(),
    change_from_first_recorded_max_weight_lb = numeric(),
    latest_exercise_volume_lb = numeric(),
    all_time_highest_exercise_volume_lb = numeric(),
    has_repeated_observations = logical(),
    progress_note = character()
  )
}

progress_note <- function(has_repeated_observations, change_lb) {
  dplyr::case_when(
    !has_repeated_observations ~ "Only one workout recorded",
    is.na(change_lb) ~ "Recorded max change unavailable",
    change_lb > 0 ~ paste0("Recorded max up ", scales::comma(change_lb), " lb from first logged workout"),
    change_lb < 0 ~ paste0("Recorded max down ", scales::comma(abs(change_lb)), " lb from first logged workout"),
    TRUE ~ "Recorded max unchanged from first logged workout"
  )
}

