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
