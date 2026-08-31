test_that("dashboard filter payload exposes public processed set fields", {
  skip_if_no_seed_data()

  payload <- read_lifting_sets(seed_lifting_sets_path()) |>
    dashboard_filter_payload()

  expect_named(payload, c("generated_at", "rows"))
  expect_type(payload$generated_at, "character")
  expect_s3_class(payload$rows, "data.frame")
  expect_true(nrow(payload$rows) > 0)
  expect_true(all(c(
    "activity_id", "date", "workout_name", "set_number",
    "exercise_raw", "exercise", "movement_group", "equipment_type",
    "exercise_label", "reps", "weight_lb", "volume_lb"
  ) %in% names(payload$rows)))
  expect_false(any(grepl("data/raw/workouts", unlist(payload$rows), fixed = TRUE)))
})

test_that("dashboard source defines static linked filter targets", {
  source <- paste(readLines(file.path(find_project_root(), "dashboard", "index.qmd"), warn = FALSE), collapse = "\n")

  expect_false(grepl("runtime:\\s*shiny", source))
  expect_true(grepl("zlifts-dashboard-data", source, fixed = TRUE))
  expect_true(grepl("date-start-filter", source, fixed = TRUE))
  expect_true(grepl("date-end-filter", source, fixed = TRUE))
  expect_true(grepl("exercise-filter", source, fixed = TRUE))
  expect_true(grepl("movement-filter", source, fixed = TRUE))
  expect_true(grepl("equipment-filter", source, fixed = TRUE))
  expect_true(grepl("session-volume-chart", source, fixed = TRUE))
  expect_true(grepl("exercise-volume-chart", source, fixed = TRUE))
  expect_true(grepl("max-weight-chart", source, fixed = TRUE))
  expect_true(grepl("set-performance-chart", source, fixed = TRUE))
  expect_true(grepl("exercise-progress-table", source, fixed = TRUE))
  expect_true(grepl("session-summary-table", source, fixed = TRUE))
})
test_that("dashboard filter script resizes charts after dashboard navigation", {
  script <- paste(readLines(file.path(find_project_root(), "dashboard", "zlifts-filters.js"), warn = FALSE), collapse = "\n")

  expect_true(grepl("Plotly.Plots.resize", script, fixed = TRUE))
  expect_true(grepl("ResizeObserver", script, fixed = TRUE))
})
test_that("dashboard filter payload calculates volume from reps and weight", {
  skip_if_no_seed_data()

  sets <- read_lifting_sets(seed_lifting_sets_path())
  sets <- sets[1, ]
  sets$reps <- 2L
  sets$weight_lb <- 10
  sets$volume_lb <- 999

  payload <- dashboard_filter_payload(sets)

  expect_equal(payload$rows$volume_lb, 20)
})

test_that("dashboard filter script preserves all-missing aggregate values", {
  script <- paste(readLines(file.path(find_project_root(), "dashboard", "zlifts-filters.js"), warn = FALSE), collapse = "\n")

  expect_true(grepl("sumOrMissing", script, fixed = TRUE))
  expect_false(grepl("total_reps += numberOrZero(row.reps)", script, fixed = TRUE))
  expect_false(grepl("total_volume_lb += numberOrZero(row.volume_lb)", script, fixed = TRUE))
})
