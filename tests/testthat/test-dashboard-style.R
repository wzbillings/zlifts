test_that("dashboard declares a local stylesheet", {
  config <- paste(readLines(file.path(find_project_root(), "dashboard", "_quarto.yml"), warn = FALSE), collapse = "\n")

  expect_true(grepl("styles.css", config, fixed = TRUE))
})

test_that("dashboard stylesheet keeps a restrained responsive analytical surface", {
  css_path <- file.path(find_project_root(), "dashboard", "styles.css")

  expect_true(file.exists(css_path))

  css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("--zlifts-bg", css, fixed = TRUE))
  expect_true(grepl(".zlifts-filter-grid", css, fixed = TRUE))
  expect_true(grepl(".zlifts-data-table", css, fixed = TRUE))
  expect_true(grepl("@media", css, fixed = TRUE))
  expect_false(grepl("letter-spacing:\\s*-", css))
  expect_false(grepl("radial-gradient|linear-gradient", css))
  expect_false(grepl("border-radius:\\s*(1[2-9]|[2-9][0-9])px", css))
})
