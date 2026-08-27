library(testthat)

source(file.path("scripts", "source-analysis.R"))
source_zlifts()

test_dir(file.path("tests", "testthat"), reporter = "summary")