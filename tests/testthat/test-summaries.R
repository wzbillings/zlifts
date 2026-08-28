test_that("seed set data preserve expected rows and activities", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path())

  expect_s3_class(sets, "tbl_df")
  expect_equal(nrow(sets), 105)
  expect_equal(dplyr::n_distinct(sets$activity_id), 4)
})

test_that("session summaries reproduce validated Garmin totals", {
  skip_if_no_seed_data()
  sessions <- read_lifting_sets(seed_lifting_sets_path()) |>
    summarize_sessions() |>
    dplyr::arrange(.data$date)

  expect_equal(sessions$total_volume_lb, c(18805, 25665, 33325, 37920))
  expect_equal(sessions$total_sets, c(23L, 26L, 26L, 30L))
  expect_equal(sessions$total_reps, c(336L, 348L, 380L, 428L))
})

test_that("exercise summaries use canonical exercise names and expected measures", {
  skip_if_no_seed_data()
  summaries <- read_lifting_sets(seed_lifting_sets_path()) |>
    summarize_exercises()

  expect_true(all(c(
    "activity_id", "date", "exercise", "movement_group", "equipment_type", "sets",
    "total_reps", "total_volume_lb", "max_weight_lb", "mean_weight_lb",
    "max_set_volume_lb"
  ) %in% names(summaries)))
  expect_equal(
    summaries |>
      dplyr::filter(.data$date == as.Date("2026-08-26"), .data$exercise == "Seated Leg Press", .data$equipment_type == "machine") |>
      dplyr::pull(.data$total_volume_lb),
    9125
  )
})

test_that("exercise summaries distinguish canonical equipment types", {
  skip_if_no_seed_data()
  summaries <- read_lifting_sets(seed_lifting_sets_path()) |>
    summarize_exercises()

  biceps <- summaries |>
    dplyr::filter(.data[["exercise"]] == "Biceps Curl")

  expect_setequal(biceps[["equipment_type"]], c("dumbbell", "machine"))
})

test_that("weighted set volume is reps times weight", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path())
  weighted <- sets |>
    dplyr::filter(!is.na(.data$reps), !is.na(.data$weight_lb), !is.na(.data$volume_lb))

  expect_equal(weighted$volume_lb, weighted$reps * weighted$weight_lb)
})

