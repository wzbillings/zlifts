# zlifts Feature Triage Plan

## Summary

As of August 27, 2026, `zlifts` is a dashboard-first Quarto project, not an R package. The package shell has been removed, package-era artifacts have been pruned, and GitHub Pages deploys through `.github/workflows/publish-dashboard.yml` using a Pages artifact.

The first public-site milestone is complete: the privacy boundary is documented and enforced by ignore rules, the dashboard deploys to GitHub Pages, and the progress/interactive dashboard work has been implemented. Remaining feature work is Garmin ingestion.

## Tracker Status

- Closed as completed: [#1 Interactive Plotly views](https://github.com/wzbillings/zlifts/issues/1), [#2 Data privacy boundary](https://github.com/wzbillings/zlifts/issues/2), [#3 GitHub Pages deployment](https://github.com/wzbillings/zlifts/issues/3), and [#6 Progress summary](https://github.com/wzbillings/zlifts/issues/6).
- Open: [#4 Ingestion format decision](https://github.com/wzbillings/zlifts/issues/4), pending paired Garmin HTML/FIT samples.
- Open and blocked: [#5 Idempotent importer](https://github.com/wzbillings/zlifts/issues/5), pending the #4 format decision.

## Completed Changes

- Treat `R/` as project-local analysis modules loaded via `scripts/source-analysis.R`; do not refer to `DESCRIPTION`, `NAMESPACE`, `.Rbuildignore`, `man/`, package exports, `devtools::test()`, `devtools::document()`, or `R CMD check`.
- Commit `1f4e089` documents and enforces the raw-data privacy boundary. `.gitignore` blocks raw Garmin source artifacts under `data/raw/workouts/` except that directory's README, and docs state that raw Garmin HTML/FIT exports are local-only by default.
- Commit `44462b6` adds the GitHub Pages workflow. The workflow restores `renv`, runs tests, renders `dashboard/_site`, uploads the Pages artifact, and deploys through GitHub Pages with `build_type: workflow`.
- Commit `39a1ca0` adds progress summaries and interactive dashboard views. Project-local summary functions compute progress/highlights from `data/processed/lifting_sets.csv`, and `dashboard/index.qmd` renders the Progress Highlights section without combining exact exercise variants or using 1RM/physiological-strength claims.
- Commit `39a1ca0` also preserves ggplot-returning plot functions with human-readable hover text, while `interactive_lifting_plot()` wraps them with Plotly for static hover/zoom/pan dashboard behavior. `plotly` is recorded in `renv.lock` because it provides the core static interactivity requested.
- Commit `981c251` switches the project license to AGPL v3.

## Remaining Issue Order

1. [#4 Ingestion format decision](https://github.com/wzbillings/zlifts/issues/4) - P2. Decide whether Garmin HTML/HTM or FIT should be the primary source format.
2. [#5 Idempotent importer](https://github.com/wzbillings/zlifts/issues/5) - P2. Implement after #4 chooses a source format.

## Remaining Work

For #4:

- Obtain paired Garmin Connect HTML/HTM and FIT exports for the same seed workouts.
- Prototype parsing both formats far enough to recover available strength-set data.
- Compare both parser outputs against `data/processed/lifting_sets.csv` for set counts, reps, weights, volumes, exercise-name fidelity, stable IDs, and privacy footprint.
- Write `docs/ingestion-format-decision.md` with the empirical comparison and recommendation.

For #5:

- Implement one importer for the format selected in #4 before supporting alternate formats.
- Preserve the canonical set-level data model in `data/processed/lifting_sets.csv`.
- Keep imports idempotent and report added, skipped, and failed files clearly.
- Regenerate summaries from `lifting_sets.csv` instead of committing derived summary CSVs.

## Commands

- Primary test command: `Rscript tests/testthat.R`.
- Dashboard render command: `quarto render dashboard`.
- Dependency consistency command: `Rscript -e "renv::status()"`.

## Assumptions

- Raw Garmin files remain local-only unless the maintainer explicitly approves committing reduced fixtures.
- `data/processed/lifting_sets.csv` remains the single canonical committed processed dataset.
- `archive/reference-plots/` is historical only and should not be updated as part of dashboard work.
- Daily updates remain manual normalized-row commits to `data/processed/lifting_sets.csv` until Garmin ingestion exists.
