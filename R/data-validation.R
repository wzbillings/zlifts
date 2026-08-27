#' Validate Garmin lifting set data
#'
#' Performs lightweight checks on the canonical set-level table. Missing
#' required columns are treated as errors because downstream summaries and plots
#' cannot be trusted without them. Other checks return structured pass/fail rows.
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#' @param tolerance Numeric tolerance used when comparing calculated volumes.
#'
#' @return A tibble with columns `check`, `status`, `message`, and `n`, with
#'   class `garminlifting_validation`.
#' @export
validate_lifting_data <- function(sets, tolerance = 1e-8) {
  check_required_columns(sets)

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
  false_match_flags <- !is.na(sets$volume_matches_garmin) & !sets$volume_matches_garmin

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
      "no_exact_duplicate_records",
      if (any(exact_duplicate_records)) "fail" else "pass",
      if (any(exact_duplicate_records)) "Exact duplicate set records are present." else "No exact duplicate set records were found.",
      sum(exact_duplicate_records)
    )
  )

  class(results) <- c("garminlifting_validation", class(results))
  results
}

#' @export
print.garminlifting_validation <- function(x, ...) {
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
