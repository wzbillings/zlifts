test_that("validation reports pass/fail checks", {
  skip_if_no_seed_data()
  result <- read_lifting_sets(seed_lifting_sets_path()) |>
    validate_lifting_data()

  expect_s3_class(result, "zlifts_validation")
  expect_true(all(c("check", "status", "message", "n") %in% names(result)))
  expect_true(all(result$status == "pass"))
})

test_that("validation fails clearly when a required column is missing", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path())
  bad_sets <- dplyr::select(sets, -activity_id)

  expect_error(
    validate_lifting_data(bad_sets),
    "Missing required column"
  )
})
test_that("validation accepts text volume match flags", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path())
  sets$volume_matches_garmin <- ifelse(sets$volume_matches_garmin, "True", "False")

  result <- validate_lifting_data(sets)

  expect_true(all(result$status == "pass"))
})

