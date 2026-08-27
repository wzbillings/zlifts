plot_mapping_names <- function(plot) {
  mappings <- c(
    list(plot$mapping),
    lapply(plot$layers, function(layer) layer$mapping)
  )
  unique(unlist(lapply(mappings, names), use.names = FALSE))
}

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

test_that("dashboard plots expose human-readable hover text", {
  skip_if_no_seed_data()
  sets <- read_lifting_sets(seed_lifting_sets_path())
  exercises <- summarize_exercises(sets)
  sessions <- summarize_sessions(sets)

  expect_true("text" %in% plot_mapping_names(plot_session_volume(sessions)))
  expect_true("text" %in% plot_mapping_names(plot_exercise_volume(exercises)))
  expect_true("text" %in% plot_mapping_names(plot_exercise_max_weight(exercises)))
  expect_true("text" %in% plot_mapping_names(plot_set_performance(sets)))
})

test_that("interactive conversion returns a Plotly htmlwidget", {
  skip_if_no_seed_data()
  skip_if_not_installed("plotly")

  sessions <- read_lifting_sets(seed_lifting_sets_path()) |>
    summarize_sessions()

  widget <- interactive_lifting_plot(plot_session_volume(sessions))

  expect_s3_class(widget, "plotly")
  expect_s3_class(widget, "htmlwidget")
})
