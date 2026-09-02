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
  expect_true(grepl("# Workout Detail", source, fixed = TRUE))
  expect_true(grepl("workout-date-filter", source, fixed = TRUE))
  expect_true(grepl("workout-detail-table", source, fixed = TRUE))
})
test_that("dashboard filter script resizes charts after dashboard navigation", {
  script <- paste(readLines(file.path(find_project_root(), "dashboard", "zlifts-filters.js"), warn = FALSE), collapse = "\n")

  expect_true(grepl("Plotly.Plots.resize", script, fixed = TRUE))
  expect_true(grepl("ResizeObserver", script, fixed = TRUE))
})
test_that("dashboard filter script renders workout detail table from latest logged date", {
  script <- paste(readLines(file.path(find_project_root(), "dashboard", "zlifts-filters.js"), warn = FALSE), collapse = "\n")

  expect_true(grepl("initializeWorkoutDetailDates", script, fixed = TRUE))
  expect_true(grepl("state.latestWorkoutDate", script, fixed = TRUE))
  expect_true(grepl("renderWorkoutDetail", script, fixed = TRUE))
  expect_true(grepl("workout-detail-table", script, fixed = TRUE))
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

test_that('dashboard payload exposes variant-aware exercise labels', {
  sets <- tibble::tibble(
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

  payload <- dashboard_filter_payload(sets)

  expect_true('exercise_variant' %in% names(payload[['rows']]))
  expect_equal(payload[['rows']][['exercise_label']], c('Row (single-pulley)', 'Row (double-pulley)'))
})
