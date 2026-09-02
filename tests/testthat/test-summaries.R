test_that("processed set data keep canonical schema and populated activities", {
  skip_if_no_processed_data()
  sets <- read_processed_lifting_sets(apply_mapping = FALSE)
  blank_activity <- is.na(sets$activity_id) | trimws(as.character(sets$activity_id)) == ""

  expect_s3_class(sets, "tbl_df")
  expect_true(nrow(sets) > 0)
  expect_true(all(canonical_lifting_set_columns() %in% names(sets)))
  expect_false(any(blank_activity))
  expect_true(dplyr::n_distinct(sets$activity_id) > 0)
})

test_that("processed fixture validates against fixture workout metadata", {
  sets <- read_fixture_lifting_sets()
  workouts <- read_fixture_workouts()

  result <- validate_lifting_data(
    sets,
    exercise_mapping = fixture_exercise_mapping_path(),
    workouts = workouts
  )

  expect_true(all(result$status == "pass"))
})

test_that("session summaries reproduce processed fixture totals", {
  sessions <- read_fixture_lifting_sets() |>
    summarize_sessions() |>
    dplyr::arrange(.data$date)

  expect_equal(sessions$total_volume_lb, c(3060, 2890, 3520))
  expect_equal(sessions$total_sets, c(4L, 4L, 4L))
  expect_equal(sessions$total_reps, c(40L, 38L, 36L))
})

test_that("exercise summaries use fixture canonical exercise names and expected measures", {
  summaries <- read_fixture_lifting_sets() |>
    summarize_exercises()

  expect_true(all(c(
    "activity_id", "date", "exercise", "movement_group", "equipment_type", "sets",
    "total_reps", "total_volume_lb", "max_weight_lb", "mean_weight_lb",
    "max_set_volume_lb"
  ) %in% names(summaries)))
  expect_equal(
    summaries |>
      dplyr::filter(.data$date == as.Date("2026-01-05"), .data$exercise == "Seated Leg Press", .data$equipment_type == "machine") |>
      dplyr::pull(.data$total_volume_lb),
    2780
  )
})

test_that("exercise summaries distinguish fixture canonical equipment types", {
  summaries <- read_fixture_lifting_sets() |>
    summarize_exercises()

  biceps <- summaries |>
    dplyr::filter(.data[["exercise"]] == "Biceps Curl")

  expect_setequal(biceps[["equipment_type"]], c("dumbbell", "machine"))
})

test_that("processed set volume is reps times weight where both inputs are present", {
  skip_if_no_processed_data()
  sets <- read_processed_lifting_sets(apply_mapping = FALSE)
  weighted <- sets |>
    dplyr::filter(!is.na(.data$reps), !is.na(.data$weight_lb))

  expect_equal(weighted$volume_lb, weighted$reps * weighted$weight_lb)
})

test_variant_sets <- function() {
  tibble::tibble(
    activity_id = c('single-activity', 'double-activity'),
    day = c(1L, 2L),
    date = as.Date(c('2026-01-01', '2026-01-03')),
    date_source = c('fixture', 'fixture'),
    workout_name = c('Single Row Day', 'Double Row Day'),
    set_number = c(1L, 1L),
    exercise_raw = c('Row', 'Row'),
    exercise = c('Row', 'Row'),
    exercise_variant = c('single-pulley', 'double-pulley'),
    movement_group = c('Row', 'Row'),
    equipment_type = c('machine', 'machine'),
    set_type = c(NA_character_, NA_character_),
    time_raw = c('0:30', '0:30'),
    time_seconds = c(30, 30),
    rest_raw = c('1:00', '1:00'),
    rest_seconds = c(60, 60),
    reps = c(10L, 10L),
    weight_lb = c(70, 35),
    garmin_volume_lb = c(700, 350),
    volume_lb = c(700, 350),
    volume_matches_garmin = c(TRUE, TRUE)
  )
}

test_that('exercise summaries distinguish setup variants within one movement', {
  summaries <- summarize_exercises(test_variant_sets())

  expect_equal(nrow(summaries), 2L)
  expect_setequal(summaries[['exercise_variant']], c('single-pulley', 'double-pulley'))
  expect_equal(
    summaries |>
      dplyr::filter(.data[['exercise_variant']] == 'single-pulley') |>
      dplyr::pull(.data[['max_weight_lb']]),
    70
  )
  expect_equal(
    summaries |>
      dplyr::filter(.data[['exercise_variant']] == 'double-pulley') |>
      dplyr::pull(.data[['max_weight_lb']]),
    35
  )
})
