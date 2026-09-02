#' Validate Garmin lifting set data
#'
#' Performs lightweight checks on the canonical set-level table. Missing
#' required columns are treated as errors because downstream summaries and plots
#' cannot be trusted without them. Other checks return structured pass/fail rows.
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#' @param tolerance Numeric tolerance used when comparing calculated volumes.
#' @param exercise_mapping Optional mapping tibble or path used to verify
#'   exercise, movement_group, and equipment_type fields.
#' @param workouts Optional workout metadata tibble or path used to verify that
#'   duplicated set-level workout fields match data/processed/workouts.csv.
#'
#' @return A tibble with columns `check`, `status`, `message`, and `n`, with
#'   class `zlifts_validation`.
resolve_validation_workouts <- function(sets, workouts = NULL) {
  if (!is.null(workouts)) {
    return(resolve_workouts(workouts))
  }

  workouts_path <- attr(sets, "workouts_path", exact = TRUE)
  if (is.character(workouts_path) && length(workouts_path) == 1L && file.exists(workouts_path)) {
    return(read_workouts(workouts_path))
  }

  NULL
}

same_workout_value <- function(x, y) {
  x <- as.character(x)
  y <- as.character(y)
  (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & x == y)
}

workout_metadata_consistency <- function(sets, workouts) {
  set_workouts <- derive_workouts_from_sets(sets)
  workouts <- resolve_workouts(workouts)

  duplicate_set_metadata <- set_workouts |>
    dplyr::count(.data$activity_id, name = "n") |>
    dplyr::filter(.data$n > 1)
  duplicate_workout_metadata <- workouts |>
    dplyr::count(.data$activity_id, name = "n") |>
    dplyr::filter(.data$n > 1)

  joined <- dplyr::full_join(
    set_workouts,
    workouts,
    by = "activity_id",
    suffix = c("_sets", "_workouts")
  )

  missing_from_sets <- is.na(joined$day_sets) & is.na(joined$date_sets) & is.na(joined$workout_name_sets)
  missing_from_workouts <- is.na(joined$day_workouts) & is.na(joined$date_workouts) & is.na(joined$workout_name_workouts)
  field_mismatch <- !missing_from_sets & !missing_from_workouts & (
    !same_workout_value(joined$day_sets, joined$day_workouts) |
      !same_workout_value(joined$date_sets, joined$date_workouts) |
      !same_workout_value(joined$date_source_sets, joined$date_source_workouts) |
      !same_workout_value(joined$workout_name_sets, joined$workout_name_workouts)
  )

  failures <- nrow(duplicate_set_metadata) +
    nrow(duplicate_workout_metadata) +
    sum(missing_from_sets | missing_from_workouts | field_mismatch, na.rm = TRUE)

  list(
    failures = failures,
    message = if (failures > 0) {
      "Workout metadata does not match set rows."
    } else {
      "Workout metadata matches set rows."
    }
  )
}

resolve_validation_exercise_setups <- function(sets, exercise_setups = NULL) {
  if (!is.null(exercise_setups)) {
    return(resolve_exercise_setups(exercise_setups))
  }

  exercise_setups_path <- attr(sets, 'exercise_setups_path', exact = TRUE)
  if (is.character(exercise_setups_path) && length(exercise_setups_path) == 1L && file.exists(exercise_setups_path)) {
    return(read_exercise_setups(exercise_setups_path))
  }

  NULL
}

exercise_setup_consistency <- function(sets, exercise_setups) {
  assigned <- attach_exercise_setup_fields(sets, exercise_setups)
  expected <- coalesce_optional_text(assigned[['.setup_exercise_variant']], NA_character_)
  actual <- coalesce_optional_text(assigned[['exercise_variant']], NA_character_)
  mismatch <- !is.na(expected) & (is.na(actual) | actual != expected)

  list(
    failures = sum(mismatch, na.rm = TRUE),
    message = if (any(mismatch, na.rm = TRUE)) {
      'Exercise setup assignments do not match set rows.'
    } else {
      'Exercise setup assignments match set rows.'
    }
  )
}

validate_lifting_data <- function(sets, tolerance = 1e-8, exercise_mapping = NULL, workouts = NULL, exercise_setups = NULL) {
  check_required_columns(sets)
  volume_matches_garmin <- parse_logical_text(sets$volume_matches_garmin)

  blank_activity <- is.na(sets$activity_id) | trimws(as.character(sets$activity_id)) == ""
  bad_set_numbers <- is.na(sets$set_number) | sets$set_number <= 0 | sets$set_number != floor(sets$set_number)
  duplicate_set_numbers <- sets |>
    tidyr::drop_na(dplyr::all_of(c("activity_id", "set_number"))) |>
    dplyr::count(.data$activity_id, .data$set_number, name = "n") |>
    dplyr::filter(.data$n > 1)
  bad_reps <- !is.na(sets$reps) & sets$reps < 0
  bad_weights <- !is.na(sets$weight_lb) & sets$weight_lb < 0

  comparable_volume <- !is.na(sets$reps) & !is.na(sets$weight_lb) & !is.na(sets$volume_lb)
  volume_mismatch <- comparable_volume & abs(sets$volume_lb - (sets$reps * sets$weight_lb)) > tolerance

  comparable_garmin <- !is.na(sets$garmin_volume_lb) & !is.na(sets$volume_lb)
  garmin_mismatch <- comparable_garmin & abs(sets$garmin_volume_lb - sets$volume_lb) > tolerance

  exact_duplicate_records <- duplicated(sets) | duplicated(sets, fromLast = TRUE)
  false_match_flags <- !is.na(volume_matches_garmin) & !volume_matches_garmin

  if (is.null(exercise_mapping)) {
    exercise_mapping <- attr(sets, "exercise_mapping_path", exact = TRUE)
  }
  mapped_exercises <- attach_exercise_mapping_fields(
    dplyr::select(sets, dplyr::all_of(c("exercise_raw", "exercise", "exercise_variant", "movement_group", "equipment_type"))),
    exercise_mapping
  )
  unmapped_exercises <- unique(mapped_exercises$exercise_raw[
    is.na(mapped_exercises$.mapped_exercise) &
      !is.na(mapped_exercises$exercise_raw) &
      nzchar(trimws(mapped_exercises$exercise_raw))
  ])
  exercise_name_mismatch <- !is.na(mapped_exercises$.mapped_exercise) &
    (is.na(mapped_exercises$exercise) | mapped_exercises$exercise != mapped_exercises$.mapped_exercise)
  movement_group_mismatch <- !is.na(mapped_exercises$.mapped_movement_group) &
    (is.na(mapped_exercises$movement_group) | mapped_exercises$movement_group != mapped_exercises$.mapped_movement_group)
  equipment_type_mismatch <- !is.na(mapped_exercises$.mapped_equipment_type) &
    (is.na(mapped_exercises$equipment_type) | mapped_exercises$equipment_type != mapped_exercises$.mapped_equipment_type)
  exercise_mapping_mismatch <- rowSums(
    cbind(exercise_name_mismatch, movement_group_mismatch, equipment_type_mismatch),
    na.rm = TRUE
  ) > 0
  exercise_mapping_failures <- length(unmapped_exercises) + sum(exercise_mapping_mismatch, na.rm = TRUE)
  exercise_mapping_message <- dplyr::case_when(
    length(unmapped_exercises) > 0 ~ paste(
      "Unmapped Garmin exercise name(s):",
      paste(unmapped_exercises, collapse = ", ")
    ),
    any(exercise_mapping_mismatch, na.rm = TRUE) ~ "Mapped exercise, movement_group, or equipment_type fields do not match the exercise mapping.",
    TRUE ~ "Exercise names are covered by the exercise mapping."
  )

  exercise_setup_metadata <- resolve_validation_exercise_setups(sets, exercise_setups)
  exercise_setup_check <- if (is.null(exercise_setup_metadata)) {
    NULL
  } else {
    exercise_setup_consistency(sets, exercise_setup_metadata)
  }
  exercise_setup_row <- if (is.null(exercise_setup_check)) {
    NULL
  } else {
    check_row(
      'exercise_setup_assignments_match_sets',
      if (exercise_setup_check[['failures']] > 0) 'fail' else 'pass',
      exercise_setup_check[['message']],
      exercise_setup_check[['failures']]
    )
  }

  workout_metadata <- resolve_validation_workouts(sets, workouts)
  workout_metadata_check <- if (is.null(workout_metadata)) {
    NULL
  } else {
    workout_metadata_consistency(sets, workout_metadata)
  }
  workout_metadata_row <- if (is.null(workout_metadata_check)) {
    NULL
  } else {
    check_row(
      "workout_metadata_matches_sets",
      if (workout_metadata_check$failures > 0) "fail" else "pass",
      workout_metadata_check$message,
      workout_metadata_check$failures
    )
  }

  results <- dplyr::bind_rows(
    check_row("required_columns", "pass", "All required columns are present.", 0L),
    check_row(
      "activity_ids_populated",
      if (any(blank_activity)) "fail" else "pass",
      if (any(blank_activity)) "Activity IDs must be populated." else "All activity IDs are populated.",
      sum(blank_activity)
    ),
    check_row(
      "set_numbers_sensible",
      if (any(bad_set_numbers)) "fail" else "pass",
      if (any(bad_set_numbers)) "Set numbers must be positive whole numbers." else "Set numbers are positive whole numbers.",
      sum(bad_set_numbers)
    ),
    check_row(
      "set_numbers_unique_within_activity",
      if (nrow(duplicate_set_numbers) > 0) "fail" else "pass",
      if (nrow(duplicate_set_numbers) > 0) "Set numbers should not repeat within an activity." else "Set numbers are unique within each activity.",
      nrow(duplicate_set_numbers)
    ),
    check_row(
      "reps_nonnegative",
      if (any(bad_reps)) "fail" else "pass",
      if (any(bad_reps)) "Repetitions must be nonnegative when present." else "Repetitions are nonnegative where present.",
      sum(bad_reps)
    ),
    check_row(
      "weights_nonnegative",
      if (any(bad_weights)) "fail" else "pass",
      if (any(bad_weights)) "Weights must be nonnegative when present." else "Weights are nonnegative where present.",
      sum(bad_weights)
    ),
    check_row(
      "volume_matches_reps_times_weight",
      if (any(volume_mismatch)) "fail" else "pass",
      if (any(volume_mismatch)) "Recorded volume differs from reps * weight for at least one set." else "Recorded volume matches reps * weight where comparable.",
      sum(volume_mismatch)
    ),
    check_row(
      "garmin_volume_matches_volume",
      if (any(garmin_mismatch) || any(false_match_flags)) "fail" else "pass",
      if (any(garmin_mismatch) || any(false_match_flags)) "Garmin volume and calculated volume disagree for at least one set." else "Garmin volume and calculated volume agree where comparable.",
      sum(garmin_mismatch | false_match_flags)
    ),
    check_row(
      "exercise_names_mapped",
      if (exercise_mapping_failures > 0) "fail" else "pass",
      exercise_mapping_message,
      exercise_mapping_failures
    ),
    exercise_setup_row,
    workout_metadata_row,
    check_row(
      "no_exact_duplicate_records",
      if (any(exact_duplicate_records)) "fail" else "pass",
      if (any(exact_duplicate_records)) "Exact duplicate set records are present." else "No exact duplicate set records were found.",
      sum(exact_duplicate_records)
    )
  )

  class(results) <- c("zlifts_validation", class(results))
  results
}

print.zlifts_validation <- function(x, ...) {
  failed <- sum(x$status == "fail", na.rm = TRUE)
  warned <- sum(x$status == "warn", na.rm = TRUE)
  passed <- sum(x$status == "pass", na.rm = TRUE)

  cat("Garmin lifting data validation: ")
  cat(passed, " passed", sep = "")
  if (warned > 0) {
    cat(", ", warned, " warnings", sep = "")
  }
  if (failed > 0) {
    cat(", ", failed, " failed", sep = "")
  }
  cat("\n")
  NextMethod()
}
