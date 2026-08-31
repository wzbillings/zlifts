update_workouts_script_path <- function() {
  candidates <- c(
    file.path("scripts", "update-workouts.R"),
    file.path("..", "..", "scripts", "update-workouts.R")
  )
  existing <- candidates[file.exists(candidates)]

  if (length(existing) == 0L) {
    return(candidates[[1]])
  }

  normalizePath(existing[[1]], mustWork = TRUE)
}

test_that("daily update command accepts one importer mode and optional CSV paths", {
  expect_true(file.exists(update_workouts_script_path()))

  if (!file.exists(update_workouts_script_path())) {
    return(invisible())
  }

  source(update_workouts_script_path())

  checked <- parse_update_args(c("--check", "new-workout.csv"))
  written <- parse_update_args(c("--write", "first.csv", "second.csv"))

  expect_identical(checked$mode, "--check")
  expect_identical(checked$paths, "new-workout.csv")
  expect_identical(written$mode, "--write")
  expect_identical(written$paths, c("first.csv", "second.csv"))
  expect_error(parse_update_args(character()), "Usage:")
  expect_error(parse_update_args(c("--check", "--write")), "Usage:")
  expect_error(parse_update_args(c("--dry-run")), "Unknown option")
})

test_that("daily update command orders importer, tests, render, and write status", {
  expect_true(file.exists(update_workouts_script_path()))

  if (!file.exists(update_workouts_script_path())) {
    return(invisible())
  }

  source(update_workouts_script_path())

  expect_identical(
    update_command_plan("--check", "new-workout.csv"),
    list(
      list("Rscript", c("scripts/ingest-workouts.R", "--check", "new-workout.csv"), "importer"),
      list("Rscript", c("tests/testthat.R"), "tests"),
      list("quarto", c("render", "dashboard"), "dashboard render")
    )
  )
  expect_identical(
    update_command_plan("--write", character()),
    list(
      list("Rscript", c("scripts/ingest-workouts.R", "--write"), "importer"),
      list("Rscript", c("tests/testthat.R"), "tests"),
      list("quarto", c("render", "dashboard"), "dashboard render"),
      list("git", c("status", "--short"), "git status")
    )
  )
})
