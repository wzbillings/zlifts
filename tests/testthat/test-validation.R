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


test_that("validation fails when mapped canonical fields are missing", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)
  sets$exercise[[1]] <- NA_character_
  sets$movement_group[[2]] <- NA_character_
  sets$equipment_type[[3]] <- NA_character_

  result <- validate_lifting_data(sets)
  mapping_check <- result[result[["check"]] == "exercise_names_mapped", ]

  expect_equal(mapping_check[["status"]], "fail")
  expect_equal(mapping_check[["n"]], 3L)
  expect_match(mapping_check[["message"]], "do not match the exercise mapping", fixed = TRUE)
})

test_that("validation rejects fractional processed weights", {
  sets <- read_fixture_lifting_sets()
  sets[["weight_lb"]][[1]] <- 50.5
  sets[["volume_lb"]][[1]] <- sets[["reps"]][[1]] * sets[["weight_lb"]][[1]]
  sets[["garmin_volume_lb"]][[1]] <- sets[["volume_lb"]][[1]]
  sets[["volume_matches_garmin"]][[1]] <- TRUE

  result <- validate_lifting_data(sets)
  weight_check <- result[result[["check"]] == "weights_whole_numbers", ]

  expect_equal(weight_check[["status"]], "fail")
  expect_equal(weight_check[["n"]], 1L)
  expect_match(weight_check[["message"]], "whole numbers", fixed = TRUE)
})
