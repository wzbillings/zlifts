test_that("source_zlifts loads project-local analysis modules", {
  loader_candidates <- c(
    file.path("scripts", "source-analysis.R"),
    file.path("..", "..", "scripts", "source-analysis.R"),
    file.path("..", "..", "..", "scripts", "source-analysis.R")
  )
  loader_path <- loader_candidates[file.exists(loader_candidates)][[1]]

  source(loader_path, local = TRUE)

  analysis_env <- new.env(parent = globalenv())
  repo_root <- find_project_root()
  source_zlifts(repo_root, envir = analysis_env)

  expect_true(all(c(
    "read_lifting_sets",
    "read_exercise_mapping",
    "apply_exercise_mapping",
    "validate_lifting_data",
    "summarize_sessions",
    "summarize_exercises",
    "plot_session_volume"
  ) %in% ls(analysis_env)))

  sets <- analysis_env$read_lifting_sets(file.path(repo_root, "data", "processed", "lifting_sets.csv"))

  expect_s3_class(sets, "tbl_df")
  expect_equal(nrow(sets), 75)
})
