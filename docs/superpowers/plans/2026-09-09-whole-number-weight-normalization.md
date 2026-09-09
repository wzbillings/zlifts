# Whole-number Weight Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Normalize every populated Garmin lifting weight to a whole pound by truncating fractional values and recompute processed volume fields from that normalized weight.

**Architecture:** Normalize at the Garmin Splits import boundary so every new processed row is canonical before mapping, setup assignment, validation, or dashboard use. Preserve source-quality detection by comparing Garmin's original volume with the original reps and weight before replacing processed volume values. Add a validator invariant for whole-number weights and migrate the two existing fractional processed rows.

**Tech Stack:** R 4.6, readr, dplyr, tibble, testthat, Quarto

## Global Constraints

- Truncate populated weights toward zero; do not round to the nearest pound.
- Preserve missing weights, reps, and Garmin volumes rather than inferring them.
- Calculate volume_lb as reps * weight_lb after weight normalization.
- Populate normalized garmin_volume_lb only when Garmin supplied a volume and the normalized calculation is available.
- Evaluate volume_matches_garmin against Garmin's original reps, weight, and volume before normalization.
- Keep raw Garmin exports unchanged and local-only.
- Add no dependencies; use packages already recorded in renv.lock.
- Preserve the current uncommitted September 9 ingest changes and leave docs/research/ untouched.
- Run validation before rendering whenever processed data changes.

---

### Task 0: Checkpoint the current September 9 ingest

**Files:**
- Modify: data/processed/exercise_setups.csv
- Modify: data/processed/lifting_sets.csv
- Modify: data/processed/workouts.csv
- Modify: tests/testthat/test-exercise-mapping.R

**Interfaces:**
- Consumes: The already-verified activity 24295061347 ingest in the current working tree.
- Produces: A committed baseline containing workout day 8, 24 set rows, and the inferred single-pulley Row setup.

- [ ] **Step 1: Confirm only the intended ingest files are selected**

Run:

~~~powershell
git status --short
git diff -- data/processed/exercise_setups.csv data/processed/lifting_sets.csv data/processed/workouts.csv tests/testthat/test-exercise-mapping.R
~~~

Expected: the four listed files contain only the September 9 activity and its Row setup/test expectation; this implementation plan and docs/research/ remain untracked and untouched.

- [ ] **Step 2: Re-run the baseline test suite**

Run: Rscript tests/testthat.R

Expected: PASS with no test failures.

- [ ] **Step 3: Commit the existing ingest separately**

~~~powershell
git add data/processed/exercise_setups.csv data/processed/lifting_sets.csv data/processed/workouts.csv tests/testthat/test-exercise-mapping.R
git commit -m "data: ingest 2026-09-09 workout"
~~~

Expected: one commit containing only the four ingest-related files.

---

### Task 1: Normalize weights and processed volumes at import

**Files:**
- Modify: tests/testthat/test-garmin-splits-import.R:104-160
- Modify: R/garmin-splits-import.R:248-280

**Interfaces:**
- Consumes: Garmin Splits Reps, Weight, and Volume text columns parsed by parse_garmin_numeric_column() and parse_garmin_integer_column().
- Produces: parse_garmin_splits_csv() rows whose weight_lb is truncated, whose processed volume fields use that weight, and whose volume_matches_garmin still represents the original Garmin calculation.

- [ ] **Step 1: Write failing importer tests**

In the existing "computes canonical volume" test, replace the final assertions with:

~~~r
  expect_equal(parsed$volume_lb, 315)
  expect_equal(parsed$garmin_volume_lb, 315)
  expect_false(parsed$volume_matches_garmin)
~~~

Add this test immediately afterward:

~~~r
test_that("Garmin Splits parser truncates fractional weights and normalizes volumes", {
  splits_path <- file.path(tempdir(), "2026-08-27-garmin-splits-999111230.csv")
  write_splits_csv(
    splits_path,
    list(
      Set = c(1L, 2L, 3L),
      "Exercise Name" = rep("Chest Press with Band", 3),
      Time = rep("0:30", 3),
      Rest = rep("1:00", 3),
      Reps = c(15L, 10L, 10L),
      Weight = c("210.5 lbs", "65 lbs", "N/A"),
      Volume = c("3157.5 lbs", "650 lbs", "500 lbs")
    )
  )

  parsed <- parse_garmin_splits_csv(
    splits_path,
    exercise_mapping = test_import_mapping(),
    day = 1L
  )

  expect_equal(parsed$weight_lb, c(210, 65, NA_real_))
  expect_equal(parsed$garmin_volume_lb, c(3150, 650, NA_real_))
  expect_equal(parsed$volume_lb, c(3150, 650, NA_real_))
  expect_equal(parsed$volume_matches_garmin, c(TRUE, TRUE, NA))
})
~~~

- [ ] **Step 2: Run tests to verify RED**

Run: Rscript tests/testthat.R

Expected: FAIL because the current parser retains 210.5 and 999 in processed fields instead of returning 210 and recomputed volumes.

- [ ] **Step 3: Implement normalization in the parser**

Replace the current weight/volume block in parse_garmin_splits_csv() with:

~~~r
  reps <- parse_garmin_integer_column(source[["Reps"]], "Reps")
  source_weight_lb <- parse_garmin_numeric_column(source[["Weight"]], "Weight")
  source_garmin_volume_lb <- parse_garmin_numeric_column(source[["Volume"]], "Volume")

  source_volume_lb <- reps * source_weight_lb
  comparable_garmin_volume <- !is.na(source_garmin_volume_lb) & !is.na(source_volume_lb)
  volume_matches_garmin <- rep(NA, length(source_volume_lb))
  volume_matches_garmin[comparable_garmin_volume] <-
    abs(source_garmin_volume_lb[comparable_garmin_volume] -
      source_volume_lb[comparable_garmin_volume]) <= tolerance

  weight_lb <- trunc(source_weight_lb)
  volume_lb <- reps * weight_lb
  garmin_volume_lb <- volume_lb
  garmin_volume_lb[is.na(source_garmin_volume_lb)] <- NA_real_
~~~

Keep the existing tibble column assignments unchanged so they receive the normalized local variables.

- [ ] **Step 4: Run tests to verify GREEN**

Run: Rscript tests/testthat.R

Expected: PASS, including the fractional-weight test, unrelated Garmin mismatch test, and missing-value tests.

- [ ] **Step 5: Commit importer behavior**

~~~powershell
git add R/garmin-splits-import.R tests/testthat/test-garmin-splits-import.R
git commit -m "feat: normalize fractional Garmin weights"
~~~

---

### Task 2: Enforce the invariant and migrate processed data

**Files:**
- Modify: tests/testthat/test-validation.R:1-45
- Modify: R/data-validation.R:105-245
- Modify: data/processed/lifting_sets.csv:92,189

**Interfaces:**
- Consumes: Canonical set rows passed to validate_lifting_data().
- Produces: A weights_whole_numbers validation row and processed data with no fractional weight_lb values.

- [ ] **Step 1: Write the failing validation test**

Append this focused test to tests/testthat/test-validation.R:

~~~r
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
~~~

- [ ] **Step 2: Run tests to verify RED**

Run: Rscript tests/testthat.R

Expected: FAIL because validate_lifting_data() does not yet return weights_whole_numbers.

- [ ] **Step 3: Add the whole-number validation check**

After bad_weights is calculated in R/data-validation.R, add:

~~~r
  fractional_weights <- !is.na(sets$weight_lb) & sets$weight_lb != trunc(sets$weight_lb)
~~~

Immediately after the weights_nonnegative result row, add:

~~~r
    check_row(
      "weights_whole_numbers",
      if (any(fractional_weights)) "fail" else "pass",
      if (any(fractional_weights)) "Weights must be whole numbers when present." else "Weights are whole numbers where present.",
      sum(fractional_weights)
    ),
~~~

- [ ] **Step 4: Migrate the two existing fractional rows**

In data/processed/lifting_sets.csv, change only these keys:

- Activity 24147071341, set 16: weight 100.5 to 100; garmin_volume_lb and volume_lb 2010 to 2000.
- Activity 24295061347, set 3: weight 210.5 to 210; garmin_volume_lb and volume_lb 3157.5 to 3150.
- Preserve volume_matches_garmin as TRUE for both because each original Garmin volume agreed with the original reps and weight.

- [ ] **Step 5: Run validation and tests to verify GREEN**

Run:

~~~powershell
Rscript tests/testthat.R
Rscript --vanilla -e "source('scripts/source-analysis.R'); source_zlifts('.'); sets <- read_lifting_sets('data/processed/lifting_sets.csv'); result <- validate_lifting_data(sets); print(result); stopifnot(all(result[['status']] == 'pass'))"
~~~

Expected: the full suite passes; validation includes weights_whole_numbers with status pass and n = 0.

- [ ] **Step 6: Commit validation and migration**

~~~powershell
git add R/data-validation.R tests/testthat/test-validation.R data/processed/lifting_sets.csv
git commit -m "fix(data): enforce whole-number lifting weights"
~~~

---

### Task 3: Document and verify the end-to-end workflow

**Files:**
- Add: docs/superpowers/plans/2026-09-09-whole-number-weight-normalization.md
- Modify: README.md:9-12,109-125
- Modify: data/processed/README.md:14

**Interfaces:**
- Consumes: The normalization and validation behavior from Tasks 1 and 2.
- Produces: User-facing ingestion documentation and fresh evidence that parsing, validation, tests, and dashboard rendering agree.

- [ ] **Step 1: Document the processed-data rule**

Add this paragraph to the data-model section of README.md:

~~~markdown
Weights are normalized to whole pounds by truncating fractional Garmin values toward zero. Both garmin_volume_lb and volume_lb are recomputed as reps * weight_lb from the normalized weight when the required source values are present. volume_matches_garmin still records whether Garmin's original volume agreed with its original reps and weight.
~~~

Add this sentence to data/processed/README.md:

~~~markdown
The importer truncates fractional Garmin weights toward zero and recomputes processed volume fields from the normalized whole-pound weight. Validation rejects fractional processed weights.
~~~

- [ ] **Step 2: Verify the raw September 9 export parses to normalized values**

Run:

~~~powershell
Rscript --vanilla -e "source('scripts/source-analysis.R'); source_zlifts('.'); rows <- parse_garmin_splits_csv('data/raw/workouts/2026-09-09-garmin-splits-24295061347.csv', exercise_mapping_path='data/processed/exercise_mapping.csv', day=8L); stopifnot(rows[['weight_lb']][[3]] == 210, rows[['garmin_volume_lb']][[3]] == 3150, rows[['volume_lb']][[3]] == 3150, isTRUE(rows[['volume_matches_garmin']][[3]])); cat('normalized parser check passed\n')"
~~~

Expected: normalized parser check passed.

- [ ] **Step 3: Run the complete verification workflow**

Run:

~~~powershell
Rscript tests/testthat.R
quarto render dashboard
git diff --check
git status --short
~~~

Expected: all tests pass, dashboard/_site/index.html renders successfully, git diff --check reports no errors, and status contains the intended documentation changes plus the untracked implementation plan and pre-existing docs/research/ directory.

- [ ] **Step 4: Commit documentation**

~~~powershell
git add README.md data/processed/README.md docs/superpowers/plans/2026-09-09-whole-number-weight-normalization.md
git commit -m "docs: document whole-number weight normalization"
~~~

- [ ] **Step 5: Confirm final history and clean scoped diff**

Run:

~~~powershell
git log -4 --oneline
git status --short
~~~
Expected: separate commits for the September 9 ingest, importer behavior, validation/data migration, and documentation; only the pre-existing docs/research/ remains untracked.
