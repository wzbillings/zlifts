# zlifts Feature Triage Plan

## Summary

As of August 27, 2026, `zlifts` is a dashboard-first Quarto project, not an R package. The package shell has been removed, package-era artifacts have been pruned, and GitHub Pages now deploys through `.github/workflows/publish-dashboard.yml` using a Pages artifact.

Recommended remaining issue order:

1. [#6 Progress summary](https://github.com/wzbillings/zlifts/issues/6) - Implemented locally and deployed; update or close after maintainer review.
2. [#1 Interactive Plotly views](https://github.com/wzbillings/zlifts/issues/1) - Implemented locally and deployed; update or close after maintainer review.
3. [#2 Data privacy boundary](https://github.com/wzbillings/zlifts/issues/2) - Raw export policy and ignore rules are implemented; update or close after maintainer review.
4. [#3 GitHub Pages deployment](https://github.com/wzbillings/zlifts/issues/3) - Workflow, Pages source configuration, and first deployment are complete; close/update the issue.
5. [#4 Ingestion format decision](https://github.com/wzbillings/zlifts/issues/4) - P2, future Garmin ingestion decision.
6. [#5 Idempotent importer](https://github.com/wzbillings/zlifts/issues/5) - P2, blocked by #4.

## Current States

- `implemented-awaiting-tracker-update`: #1, #2, #3, and #6.
- `blocked`: #4 depends on available paired Garmin HTML/FIT samples; #5 depends on #4.
- All GitHub issues should remain unchanged until the maintainer explicitly asks for tracker updates.

## Implemented Changes

- Treat `R/` as project-local analysis modules loaded via `scripts/source-analysis.R`; do not refer to `DESCRIPTION`, `NAMESPACE`, `.Rbuildignore`, `man/`, package exports, `devtools::test()`, `devtools::document()`, or `R CMD check`.
- For #2, `.gitignore` blocks raw Garmin source artifacts under `data/raw/workouts/` except that directory's README. `README.md` and `data/raw/workouts/README.md` state that raw Garmin HTML/FIT exports are local-only by default.
- For #3, `.github/workflows/publish-dashboard.yml` restores `renv`, runs tests, renders `dashboard/_site`, uploads the Pages artifact, and deploys through GitHub Pages with `build_type: workflow`.
- For #6, project-local summary functions compute progress/highlights from `data/processed/lifting_sets.csv`, and `dashboard/index.qmd` renders a Progress Highlights section without combining exact exercise variants or using 1RM/physiological-strength claims.
- For #1, existing plot functions still return ggplot objects with human-readable hover text, while `interactive_lifting_plot()` wraps them with Plotly for static hover/zoom/pan dashboard behavior. `plotly` is recorded in `renv.lock` because it provides the core static interactivity requested.
- For #4/#5, daily updates still mean committing normalized rows to `data/processed/lifting_sets.csv` until Garmin ingestion exists. Derived summary CSVs remain out of the committed canonical data model.

## Test Plan

- Primary intended test command: `Rscript tests/testthat.R`.
- Verified in this host with equivalent fallback: `Rscript -e "source('tests/testthat.R')"`.
- Dashboard render command: `quarto render dashboard`.
- Dependency consistency command: `Rscript -e "renv::status()"`.
- Deployment verification: GitHub Actions run `33094361771` completed successfully, Pages is configured with `build_type: workflow`, and `https://wzbillings.github.io/zlifts/` returned HTTP 200.
- For #4/#5 later, use reduced local fixtures for parser/importer tests; verify idempotence, clear per-file errors, and regenerated summaries from `lifting_sets.csv`.

## Assumptions

- Raw Garmin files remain local-only unless the maintainer explicitly approves committing reduced fixtures.
- `data/processed/lifting_sets.csv` remains the single canonical committed processed dataset.
- `archive/reference-plots/` is historical only and should not be updated as part of dashboard work.
- Garmin ingestion remains future work.
- No GitHub labels, comments, or issue states should be changed until the maintainer explicitly asks for tracker updates.
