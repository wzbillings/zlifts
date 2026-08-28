write_splits_csv <- function(path, rows) {
  readr::write_csv(tibble::as_tibble(rows), path)
  path
}

test_import_mapping <- function() {
  tibble::tibble(
    exercise_raw = c("Chest Press with Band", "Leg Press"),
    exercise = c("Chest Press", "Seated Leg Press"),
    movement_group = c("Chest Press", "Seated Leg Press"),
    equipment_type = c("machine", "machine"),
    review_status = c("reviewed", "reviewed"),
    notes = c(NA_character_, NA_character_)
  )
}

test_empty_existing_sets <- function() {
  read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)[0, ]
}

test_existing_sets <- function(activity_id = character()) {
  if (length(activity_id) == 0) {
    return(test_empty_existing_sets())
  }

  tibble::tibble(
    activity_id = activity_id,
    day = seq_along(activity_id),
    date = as.Date("2026-08-20") + seq_along(activity_id),
    date_source = "existing fixture",
    workout_name = paste("Existing", activity_id),
    set_number = 1L,
    exercise_raw = "Chest Press with Band",
    exercise = "Chest Press",
    movement_group = "Chest Press",
    equipment_type = "machine",
    set_type = NA_character_,
    time_raw = "0:30",
    time_seconds = 30,
    rest_raw = "1:00",
    rest_seconds = 60,
    reps = 10L,
    weight_lb = 50,
    garmin_volume_lb = 500,
    volume_lb = 500,
    volume_matches_garmin = TRUE
  )
}

write_existing_sets <- function(path, sets = test_empty_existing_sets()) {
  readr::write_csv(sets, path)
  path
}

test_that("Garmin Splits CSV parser emits canonical lifting set schema", {
  skip_if_no_seed_data()

  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111222.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = c(1L, 2L),
      "Exercise Name" = c("Chest Press with Band", "Leg Press"),
      Time = c("1:05", "1:02:03"),
      Rest = c("0:45", "2:00"),
      Reps = c(12L, 10L),
      Weight = c(50, 65),
      Volume = c(600, 650)
    )
  )

  parsed <- parse_garmin_splits_csv(
    splits_path,
    exercise_mapping = test_import_mapping(),
    day = 4L
  )

  expect_equal(names(parsed), names(read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)))
  expect_equal(parsed$activity_id, c("999111222", "999111222"))
  expect_equal(parsed$day, c(4L, 4L))
  expect_equal(parsed$date, as.Date(c("2026-08-27", "2026-08-27")))
  expect_equal(parsed$date_source, c("raw filename", "raw filename"))
  expect_equal(parsed$workout_name, c(
    "Garmin Strength 2026-08-27 (999111222)",
    "Garmin Strength 2026-08-27 (999111222)"
  ))
  expect_equal(parsed$set_number, c(1L, 2L))
  expect_equal(parsed$exercise_raw, c("Chest Press with Band", "Leg Press"))
  expect_equal(parsed$exercise, c("Chest Press", "Seated Leg Press"))
  expect_equal(parsed$movement_group, c("Chest Press", "Seated Leg Press"))
  expect_equal(parsed$equipment_type, c("machine", "machine"))
  expect_true(all(is.na(parsed$set_type)))
  expect_equal(parsed$time_raw, c("1:05", "1:02:03"))
  expect_equal(parsed$time_seconds, c(65, 3723))
  expect_equal(parsed$rest_raw, c("0:45", "2:00"))
  expect_equal(parsed$rest_seconds, c(45, 120))
  expect_equal(parsed$reps, c(12L, 10L))
  expect_equal(parsed$weight_lb, c(50, 65))
  expect_equal(parsed$garmin_volume_lb, c(600, 650))
  expect_equal(parsed$volume_lb, c(600, 650))
  expect_true(all(parsed$volume_matches_garmin))
})

test_that("Garmin Splits parser computes canonical volume from reps and weight", {
  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111223.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Chest Press with Band",
      Time = "0:30",
      Rest = "1:00",
      Reps = 7L,
      Weight = 45,
      Volume = 999
    )
  )

  parsed <- parse_garmin_splits_csv(
    splits_path,
    exercise_mapping = test_import_mapping(),
    day = 1L
  )

  expect_equal(parsed$volume_lb, 315)
  expect_equal(parsed$garmin_volume_lb, 999)
  expect_false(parsed$volume_matches_garmin)
})


test_that("Garmin Splits parser preserves declared numeric NA sentinels", {
  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111229.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = c(1L, 2L, 3L),
      "Exercise Name" = rep("Chest Press with Band", 3),
      Time = rep("0:30", 3),
      Rest = rep("1:00", 3),
      Reps = c("NA", "10", "8"),
      Weight = c("50", "N/A", "45"),
      Volume = c("500", "500", "--")
    )
  )

  parsed <- parse_garmin_splits_csv(
    splits_path,
    exercise_mapping = test_import_mapping(),
    day = 1L
  )

  expect_true(is.na(parsed$reps[[1]]))
  expect_true(is.na(parsed$weight_lb[[2]]))
  expect_true(is.na(parsed$garmin_volume_lb[[3]]))
  expect_true(is.na(parsed$volume_lb[[1]]))
  expect_true(is.na(parsed$volume_lb[[2]]))
  expect_true(is.na(parsed$volume_matches_garmin[[3]]))
})
test_that("Garmin Splits parser fails clearly for unmapped exercises", {
  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111224.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Mystery Lift",
      Time = "0:30",
      Rest = "1:00",
      Reps = 10L,
      Weight = 50,
      Volume = 500
    )
  )

  expect_error(
    parse_garmin_splits_csv(
      splits_path,
      exercise_mapping = test_import_mapping(),
      exercise_mapping_path = "data/processed/exercise_mapping.csv",
      day = 1L
    ),
    "Add mapping row"
  )
})

test_that("Garmin Splits parser fails clearly for bad filenames", {
  splits_path <- file.path(tempdir(), "workout.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Chest Press with Band",
      Time = "0:30",
      Rest = "1:00",
      Reps = 10L,
      Weight = 50,
      Volume = 500
    )
  )

  expect_error(
    parse_garmin_splits_csv(splits_path, exercise_mapping = test_import_mapping(), day = 1L),
    "YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv"
  )
})

test_that("Garmin Splits parser fails clearly for missing source columns", {
  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111225.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Chest Press with Band",
      Time = "0:30",
      Rest = "1:00",
      Reps = 10L,
      Weight = 50
    )
  )

  expect_error(
    parse_garmin_splits_csv(splits_path, exercise_mapping = test_import_mapping(), day = 1L),
    "Missing required Garmin Splits column"
  )
})

test_that("Garmin Splits check mode reports would_add without writing", {
  skip_if_no_seed_data()
  existing_path <- file.path(tempdir(), "lifting_sets-check.csv")
  write_existing_sets(existing_path)

  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111226.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Chest Press with Band",
      Time = "0:30",
      Rest = "1:00",
      Reps = 10L,
      Weight = 50,
      Volume = 500
    )
  )

  before <- readLines(existing_path, warn = FALSE)
  result <- ingest_garmin_splits(
    paths = splits_path,
    lifting_sets_path = existing_path,
    exercise_mapping = test_import_mapping(),
    write = FALSE
  )
  after <- readLines(existing_path, warn = FALSE)

  expect_equal(result$status, "would_add")
  expect_equal(result$added_rows, 1L)
  expect_equal(before, after)
})


test_that("Garmin Splits ingest report preserves actionable parse error details", {
  skip_if_no_seed_data()
  existing_path <- file.path(tempdir(), "lifting_sets-error-report.csv")
  write_existing_sets(existing_path)

  splits_path <- file.path(tempdir(), "workout.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Chest Press with Band",
      Time = "0:30",
      Rest = "1:00",
      Reps = 10L,
      Weight = 50,
      Volume = 500
    )
  )

  result <- ingest_garmin_splits(
    paths = splits_path,
    lifting_sets_path = existing_path,
    exercise_mapping = test_import_mapping(),
    write = FALSE
  )

  expect_equal(result$status, "failed")
  expect_match(result$message, "Expected filename convention", fixed = TRUE)
  expect_match(result$message, "Received: workout.csv", fixed = TRUE)
})
test_that("Garmin Splits write mode appends once and skips reruns by activity id", {
  skip_if_no_seed_data()
  existing_path <- file.path(tempdir(), "lifting_sets-write.csv")
  write_existing_sets(existing_path)

  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111227.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = c(1L, 2L),
      "Exercise Name" = c("Chest Press with Band", "Leg Press"),
      Time = c("0:30", "0:40"),
      Rest = c("1:00", "1:20"),
      Reps = c(10L, 8L),
      Weight = c(50, 65),
      Volume = c(500, 520)
    )
  )

  first <- ingest_garmin_splits(
    paths = splits_path,
    lifting_sets_path = existing_path,
    exercise_mapping = test_import_mapping(),
    write = TRUE
  )
  second <- ingest_garmin_splits(
    paths = splits_path,
    lifting_sets_path = existing_path,
    exercise_mapping = test_import_mapping(),
    write = TRUE
  )
  imported <- read_lifting_sets(existing_path, apply_mapping = FALSE)

  expect_equal(first$status, "added")
  expect_equal(first$added_rows, 2L)
  expect_equal(second$status, "skipped")
  expect_equal(second$skipped_rows, 2L)
  expect_equal(sum(imported$activity_id == "999111227"), 2L)
})


test_that("Garmin Splits importer reports duplicate files within one run accurately", {
  skip_if_no_seed_data()
  existing_path <- file.path(tempdir(), "lifting_sets-duplicate-input.csv")
  write_existing_sets(existing_path)

  raw_dir_one <- file.path(tempdir(), "raw-one")
  raw_dir_two <- file.path(tempdir(), "raw-two")
  dir.create(raw_dir_one, showWarnings = FALSE)
  dir.create(raw_dir_two, showWarnings = FALSE)

  splits_path_one <- file.path(raw_dir_one, "2026-08-27-garmin-splits-999111230.csv")
  splits_path_two <- file.path(raw_dir_two, "2026-08-27-garmin-splits-999111230.csv")
  source_rows <- list(
    Set = 1L,
    "Exercise Name" = "Chest Press with Band",
    Time = "0:30",
    Rest = "1:00",
    Reps = 10L,
    Weight = 50,
    Volume = 500
  )
  write_splits_csv(splits_path_one, source_rows)
  write_splits_csv(splits_path_two, source_rows)

  result <- ingest_garmin_splits(
    paths = c(splits_path_one, splits_path_two),
    lifting_sets_path = existing_path,
    exercise_mapping = test_import_mapping(),
    write = FALSE
  )

  expect_equal(result$status, c("would_add", "skipped"))
  expect_match(result$message[[2]], "already parsed earlier in this run", fixed = TRUE)
})
test_that("Garmin Splits importer skips existing activity ids without overwriting curated rows", {
  skip_if_no_seed_data()
  existing_path <- file.path(tempdir(), "lifting_sets-skip.csv")
  write_existing_sets(existing_path, test_existing_sets("999111228"))

  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111228.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = 1L,
      "Exercise Name" = "Leg Press",
      Time = "0:30",
      Rest = "1:00",
      Reps = 20L,
      Weight = 200,
      Volume = 4000
    )
  )

  result <- ingest_garmin_splits(
    paths = splits_path,
    lifting_sets_path = existing_path,
    exercise_mapping = test_import_mapping(),
    write = TRUE
  )
  imported <- read_lifting_sets(existing_path, apply_mapping = FALSE)

  expect_equal(result$status, "skipped")
  expect_equal(nrow(imported), 1L)
  expect_equal(imported$workout_name, "Existing 999111228")
  expect_equal(imported$exercise_raw, "Chest Press with Band")
})
