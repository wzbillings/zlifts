test_that("session progress metrics are calculated from fixture set data", {
  sets <- read_fixture_lifting_sets()

  progress <- summarize_session_progress(sets)

  expect_s3_class(progress, "tbl_df")
  expect_equal(nrow(progress), 1)
  expect_equal(progress$total_workouts, 3L)
  expect_equal(progress$total_sets, 12L)
  expect_equal(progress$total_reps, 114L)
  expect_equal(progress$latest_workout_date, as.Date("2026-01-05"))
  expect_equal(progress$latest_workout_total_volume_lb, 3520)
  expect_equal(progress$cumulative_volume_lb, 9470)
})

test_that("exercise progress uses fixture canonical names and repeated-observation status", {
  sets <- read_fixture_lifting_sets()

  progress <- summarize_exercise_progress(sets)

  expect_s3_class(progress, "tbl_df")
  expect_true(all(c(
    "exercise", "equipment_type", "workout_count", "first_workout_date", "latest_workout_date",
    "latest_recorded_max_weight_lb", "all_time_max_weight_lb",
    "change_from_first_recorded_max_weight_lb", "latest_exercise_volume_lb",
    "all_time_highest_exercise_volume_lb", "has_repeated_observations",
    "progress_note"
  ) %in% names(progress)))

  leg_press <- progress |>
    dplyr::filter(.data$exercise == "Seated Leg Press", .data$equipment_type == "machine")

  expect_equal(nrow(leg_press), 1)
  expect_equal(leg_press$workout_count, 3L)
  expect_equal(leg_press$first_workout_date, as.Date("2026-01-01"))
  expect_equal(leg_press$latest_workout_date, as.Date("2026-01-05"))
  expect_equal(leg_press$latest_recorded_max_weight_lb, 160)
  expect_equal(leg_press$all_time_max_weight_lb, 160)
  expect_equal(leg_press$change_from_first_recorded_max_weight_lb, 40)
  expect_equal(leg_press$latest_exercise_volume_lb, 2780)
  expect_equal(leg_press$all_time_highest_exercise_volume_lb, 2780)
  expect_true(leg_press$has_repeated_observations)

  biceps <- progress |>
    dplyr::filter(.data[["exercise"]] == "Biceps Curl")

  expect_setequal(biceps[["equipment_type"]], c("dumbbell", "machine"))

  lat_pull_down <- progress |>
    dplyr::filter(.data$exercise == "Lat Pull-down")

  expect_equal(nrow(lat_pull_down), 1)
  expect_equal(lat_pull_down$workout_count, 2L)
  expect_true(lat_pull_down$has_repeated_observations)
  expect_equal(lat_pull_down$change_from_first_recorded_max_weight_lb, 0)
  expect_match(lat_pull_down$progress_note, "Recorded max unchanged from first logged workout", fixed = TRUE)
})
