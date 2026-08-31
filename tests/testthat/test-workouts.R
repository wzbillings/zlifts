test_that("processed workout metadata returns one canonical row per activity", {
  skip_if_no_processed_data()

  workouts <- read_workouts(processed_workouts_path())
  sets <- read_processed_lifting_sets(apply_mapping = FALSE)
  set_activity_ids <- unique(sets$activity_id)
  blank_workout_activity <- is.na(workouts$activity_id) | trimws(as.character(workouts$activity_id)) == ""

  expect_identical(names(workouts), required_workout_columns())
  expect_false(any(blank_workout_activity))
  expect_equal(nrow(workouts), dplyr::n_distinct(workouts$activity_id))
  expect_equal(anyDuplicated(workouts$activity_id), 0L)
  expect_setequal(workouts$activity_id, set_activity_ids)
})

test_that("lifting data validation flags mismatched workout metadata", {
  skip_if_no_processed_data()

  sets <- read_processed_lifting_sets(apply_mapping = FALSE)
  workouts <- read_workouts(processed_workouts_path())
  workouts$workout_name[[1]] <- "Different workout"

  result <- validate_lifting_data(sets, workouts = workouts)
  consistency_check <- result[result$check == "workout_metadata_matches_sets", ]

  expect_equal(consistency_check$status, "fail")
  expect_equal(consistency_check$n, 1L)
  expect_match(consistency_check$message, "does not match")
})
