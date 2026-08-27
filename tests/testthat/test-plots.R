test_that("plotting functions return ggplot objects", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path())
  exercises <- summarize_exercises(sets)
  sessions <- summarize_sessions(sets)

  expect_s3_class(plot_exercise_volume(exercises), "ggplot")
  expect_s3_class(plot_exercise_max_weight(exercises), "ggplot")
  expect_s3_class(plot_set_performance(sets), "ggplot")
  expect_s3_class(plot_session_volume(sessions), "ggplot")
})

