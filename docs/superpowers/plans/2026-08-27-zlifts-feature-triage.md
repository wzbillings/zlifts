# zlifts Feature Triage Plan

## Summary

As of August 27, 2026, `zlifts` is a dashboard-first Quarto project, not an R package. Current HEAD includes the package-shell removal, package-era artifact pruning, and a local GitHub Pages workflow at `.github/workflows/publish-dashboard.yml`. The repo is currently ahead of `origin/main`, so deployment work may still need to be pushed and verified upstream.

Recommended issue order:

1. [#2 Data privacy boundary](https://github.com/wzbillings/zlifts/issues/2) - P0, still required before public confidence.
2. [#3 GitHub Pages deployment](https://github.com/wzbillings/zlifts/issues/3) - P0/P1, mostly implemented locally; finish by pushing, configuring, verifying, then closing/updating.
3. [#6 Progress summary](https://github.com/wzbillings/zlifts/issues/6) - P1, dashboard-value work.
4. [#1 Interactive Plotly views](https://github.com/wzbillings/zlifts/issues/1) - P1, dashboard polish if Plotly proves worth the added dependency.
5. [#4 Ingestion format decision](https://github.com/wzbillings/zlifts/issues/4) - P2, future Garmin ingestion decision.
6. [#5 Idempotent importer](https://github.com/wzbillings/zlifts/issues/5) - P2, blocked by #4.

## Current States

- `ready-for-agent`: #6.
- `ready-for-agent, dependency-sensitive`: #1, but require an explicit dependency-value check before adding `plotly`.
- `needs-agent-follow-through`: #3, because the workflow exists locally but still needs push/configuration/deployment verification.
- `needs-info` or `ready-for-human-policy`: #2, because representative raw Garmin files and the exact local-only policy need maintainer confirmation before finalizing docs/ignore rules.
- `blocked`: #4 depends on available paired Garmin HTML/FIT samples; #5 depends on #4.
- All GitHub issues are still open with only the `enhancement` label.

## Key Changes

- Treat `R/` as project-local analysis modules loaded via `scripts/source-analysis.R`; do not refer to `DESCRIPTION`, `NAMESPACE`, `.Rbuildignore`, `man/`, package exports, `devtools::test()`, `devtools::document()`, or `R CMD check`.
- For #2, update `.gitignore` to explicitly block raw Garmin HTML/FIT exports, strengthen `data/raw/workouts/README.md` with a local-only raw-data policy, and clarify in `README.md` that only `data/processed/lifting_sets.csv` is the canonical committed processed dataset.
- For #3, finish the already-started Pages work: push the local workflow if needed, set GitHub Pages source to "GitHub Actions", run the first deployment, verify `dashboard/_site` is deployed via Pages artifact, then comment on or close the issue.
- For #6, add project-local summary functions for progress/highlights and assemble them in `dashboard/index.qmd`; keep exact exercise variants separate and avoid 1RM or physiological-strength language.
- For #1, preserve ggplot-producing project-local plot functions, then add Quarto/Plotly conversion only where it improves exploration. Add `plotly` to `renv.lock` only after confirming hover/zoom/responsive value is worth the dependency.
- For #4/#5, assume daily updates remain manual normalized-row commits to `data/processed/lifting_sets.csv` until Garmin ingestion exists. Do not reintroduce derived committed summary CSVs.

## Test Plan

- Primary test command: `Rscript tests/testthat.R`.
- Dashboard render command: `quarto render dashboard`.
- Baseline from current inspection: `quarto render dashboard` passed; equivalent test fallback `Rscript -e "source('tests/testthat.R')"` passed after the harness failed to spawn the direct test command.
- For #2, verify ignored raw files cannot be accidentally staged and the dashboard reads only committed processed data.
- For #3, verify GitHub Actions run status, Pages URL, artifact upload, and rendered dashboard availability after push/configuration.
- For #6, add testthat coverage for progress summary calculations, insufficient-observation handling, and exact exercise-variant separation.
- For #1, keep existing ggplot return tests passing and verify rendered interactive dashboard output on desktop/mobile widths.
- For #4/#5, use reduced local fixtures for parser/importer tests; verify idempotence, clear per-file errors, and regenerated summaries from `lifting_sets.csv`.

## Assumptions

- Raw Garmin files remain local-only unless the maintainer explicitly approves committing reduced fixtures.
- `data/processed/lifting_sets.csv` remains the single canonical committed processed dataset.
- `archive/reference-plots/` is historical only and should not be updated as part of dashboard work.
- The first public-site milestone is privacy policy plus deployment verification; Garmin ingestion remains future work.
- No GitHub labels, comments, or issue states should be changed until the maintainer explicitly asks for tracker updates.
