workouts_seed_path <- function() {
  file.path(dirname(seed_lifting_sets_path()), "workouts.csv")
}

test_that("workout metadata reader returns one canonical row per activity", {
  skip_if_no_seed_data()

  workouts <- read_workouts(workouts_seed_path())
  sets <- read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)

  expect_identical(
    names(workouts),
    c("activity_id", "day", "date", "date_source", "workout_name")
  )
  expect_equal(nrow(workouts), dplyr::n_distinct(sets$activity_id))
  expect_equal(anyDuplicated(workouts$activity_id), 0L)
})

test_that("lifting data validation flags mismatched workout metadata", {
  skip_if_no_seed_data()

  sets <- read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)
  workouts <- read_workouts(workouts_seed_path())
  workouts$workout_name[[1]] <- "Different workout"

  result <- validate_lifting_data(sets, workouts = workouts)
  consistency_check <- result[result$check == "workout_metadata_matches_sets", ]

  expect_equal(consistency_check$status, "fail")
  expect_equal(consistency_check$n, 1L)
  expect_match(consistency_check$message, "does not match")
})
