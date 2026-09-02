test_that("exercise mapping covers current Garmin exercise names", {
  skip_if_no_seed_data()

  sets <- read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)
  mapping <- read_exercise_mapping()

  expect_true(all(c(
    "exercise_raw", "exercise", "movement_group", "equipment_type", "review_status", "notes"
  ) %in% names(mapping)))
  expect_true(all(unique(sets[["exercise_raw"]]) %in% mapping[["exercise_raw"]]))
})

test_that("exercise mapping includes known aliases and equipment types", {
  mapping <- read_exercise_mapping()

  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Chess Press with Band"], "Chest Press")
  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Chest Press with Band"], "Chest Press")
  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Suspension Chest Press"], "Chest Press")
  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Weighted Sliding Hip Adduction"], "Hip Adduction")
  expect_equal(mapping[["equipment_type"]][mapping[["exercise_raw"]] == "Weighted Sliding Hip Adduction"], "machine")
  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Weighted Standing Hip Abduction"], "Hip Abduction")
  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Weighted Leg Curl"], "Leg Curl")
  expect_equal(mapping[["exercise"]][mapping[["exercise_raw"]] == "Banded Tricep Extension"], "Tricep Extension")
  expect_equal(mapping[["equipment_type"]][mapping[["exercise_raw"]] == "Banded Tricep Extension"], "machine")
})

test_that("exercise mapping is applied and unmapped names fail clearly", {
  mapping <- tibble::tibble(
    exercise_raw = "Chest Press with Band",
    exercise = "Chest Press",
    movement_group = "Chest Press",
    equipment_type = "machine",
    review_status = "reviewed",
    notes = NA_character_
  )
  sets <- tibble::tibble(
    exercise_raw = c("Chest Press with Band", "Mystery Lift"),
    exercise = c("Chest Press with Band", "Mystery Lift"),
    movement_group = c("Chest press", "Mystery"),
    reps = c(10L, 10L),
    weight_lb = c(50, 50)
  )

  expect_error(
    apply_exercise_mapping(sets, mapping),
    "Unmapped Garmin exercise name"
  )

  mapped <- apply_exercise_mapping(sets[1, ], mapping)
  expect_equal(mapped[["exercise"]], "Chest Press")
  expect_equal(mapped[["movement_group"]], "Chest Press")
  expect_equal(mapped[["equipment_type"]], "machine")
  expect_equal(mapped[["exercise_raw"]], "Chest Press with Band")
})

test_mapping_for_suggestions <- function() {
  tibble::tibble(
    exercise_raw = "Chest Press with Band",
    exercise = "Chest Press",
    movement_group = "Chest Press",
    equipment_type = "machine",
    review_status = "reviewed",
    notes = NA_character_
  )
}

test_that("unmapped machine-like exercises include conservative copy-ready mapping rows", {
  mapping <- test_mapping_for_suggestions()
  sets <- tibble::tibble(exercise_raw = "Selectorized Pec Fly")

  expect_error(
    apply_exercise_mapping(sets, mapping),
    "Selectorized Pec Fly,Selectorized Pec Fly,,Selectorized Pec Fly,machine,inferred,Review suggested mapping"
  )
})

test_that("unmapped dumbbell exercises include dumbbell copy-ready mapping rows", {
  mapping <- test_mapping_for_suggestions()
  sets <- tibble::tibble(exercise_raw = "Dumbbell Lateral Raise")

  expect_error(
    apply_exercise_mapping(sets, mapping),
    "Dumbbell Lateral Raise,Dumbbell Lateral Raise,,Dumbbell Lateral Raise,dumbbell,inferred,Review suggested mapping"
  )
})

test_that("seed lifting dataset uses canonical exercise names and equipment types", {
  skip_if_no_seed_data()

  sets <- read_lifting_sets(seed_lifting_sets_path())

  expect_true("equipment_type" %in% names(sets))
  expect_true("Chest Press with Band" %in% sets[["exercise_raw"]])
  expect_false("Chest Press with Band" %in% sets[["exercise"]])
  expect_true("Chest Press" %in% sets[["exercise"]])
  expect_true("Seated Leg Press" %in% sets[["exercise"]])
  expect_true("Ab Crunch" %in% sets[["exercise"]])
  expect_true("Calf Extension" %in% sets[["exercise"]])
  expect_equal(unique(sets[["equipment_type"]][sets[["exercise_raw"]] == "Cable Biceps Curl"]), "machine")
  expect_equal(unique(sets[["equipment_type"]][sets[["exercise_raw"]] == "Dumbbell Biceps Curl"]), "dumbbell")
  expect_equal(unique(sets[["equipment_type"]][sets[["exercise_raw"]] == "Curl"]), "machine")
})

test_that("validation reports unmapped Garmin exercise names", {
  skip_if_no_seed_data()

  sets <- read_lifting_sets(seed_lifting_sets_path(), apply_mapping = FALSE)
  sets[["exercise_raw"]][[1]] <- "Mystery Lift"

  result <- validate_lifting_data(sets)
  mapping_check <- result[result[["check"]] == "exercise_names_mapped", ]

  expect_equal(mapping_check[["status"]], "fail")
  expect_match(mapping_check[["message"]], "Unmapped Garmin exercise name", fixed = TRUE)
  expect_equal(mapping_check[["n"]], 1L)
})

test_that('exercise setup overrides assign variants by activity and raw exercise', {
  sets <- tibble::tibble(
    activity_id = c('single-activity', 'double-activity'),
    exercise_raw = c('Row', 'Row'),
    exercise = c('Row', 'Row'),
    exercise_variant = c(NA_character_, NA_character_),
    movement_group = c('Row', 'Row'),
    equipment_type = c('machine', 'machine')
  )
  setups <- tibble::tibble(
    activity_id = c('single-activity', 'double-activity'),
    date = as.Date(c('2026-01-01', '2026-01-03')),
    exercise_raw = c('Row', 'Row'),
    exercise_variant = c('single-pulley', 'double-pulley'),
    review_status = c('reviewed', 'reviewed'),
    notes = c(NA_character_, NA_character_)
  )

  mapped <- apply_exercise_setups(sets, setups)

  expect_equal(mapped[['exercise_variant']], c('single-pulley', 'double-pulley'))
  expect_equal(mapped[['exercise']], c('Row', 'Row'))
  expect_equal(mapped[['movement_group']], c('Row', 'Row'))
})

test_that('processed row setup assignments distinguish current row machines', {
  skip_if_no_processed_data()

  sets <- read_processed_lifting_sets(apply_mapping = FALSE)
  row_variants <- sets |>
    dplyr::filter(.data[['exercise_raw']] == 'Row') |>
    dplyr::distinct(.data[['date']], .data[['activity_id']], .data[['exercise_variant']]) |>
    dplyr::arrange(.data[['date']])

  expect_equal(row_variants[['date']], as.Date(c(
    '2026-08-22', '2026-08-24', '2026-08-26',
    '2026-08-28', '2026-08-31', '2026-09-02'
  )))
  expect_equal(row_variants[['exercise_variant']], c(
    'single-pulley', 'double-pulley', 'double-pulley',
    'single-pulley', 'single-pulley', 'double-pulley'
  ))
})
