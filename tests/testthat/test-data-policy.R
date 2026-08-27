test_that("raw Garmin exports are ignored by repository policy", {
  repo_root <- find_project_root()
  skip_if(
    system2("git", "--version", stdout = NULL, stderr = NULL) != 0,
    "git is required to verify ignore policy"
  )

  raw_export_paths <- file.path(
    "data",
    "raw",
    "workouts",
    c("activity.fit", "activity.FIT", "activity.html", "activity.htm")
  )

  ignored <- vapply(
    raw_export_paths,
    function(path) {
      system2(
        "git",
        c(
          "-c", paste0("safe.directory=", repo_root),
          "-C", repo_root,
          "check-ignore", "--no-index", "-q", path
        ),
        stdout = NULL,
        stderr = NULL
      ) == 0
    },
    logical(1)
  )

  expect_true(
    all(ignored),
    info = paste("Not ignored:", paste(raw_export_paths[!ignored], collapse = ", "))
  )
})

test_that("raw workout documentation states the local-only data policy", {
  repo_root <- find_project_root()
  raw_readme <- readLines(
    file.path(repo_root, "data", "raw", "workouts", "README.md"),
    warn = FALSE
  )

  expect_true(any(grepl("local-only", raw_readme, fixed = TRUE)))
  expect_true(any(grepl("Garmin", raw_readme, fixed = TRUE)))
  expect_true(any(grepl("HTML", raw_readme, fixed = TRUE)))
  expect_true(any(grepl("FIT", raw_readme, fixed = TRUE)))
})
