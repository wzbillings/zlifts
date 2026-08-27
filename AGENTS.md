# AGENTS.md

## Summary

Treat this repository as a Quarto dashboard project for Garmin lifting analysis. The main output is a GitHub Pages site rendered from committed workout data. R code in this repo is project-local analysis code for loading, validating, summarizing, and plotting that data.

Prefer changes that make this workflow clearer:

```text
committed workout data -> validation -> summaries and plots -> Quarto dashboard -> GitHub Pages
```

## Repository Map

- `dashboard/`: Quarto website and dashboard source. `dashboard/index.qmd` is the main published page until the dashboard is intentionally split.
- `data/processed/lifting_sets.csv`: canonical set-level dataset. Summary CSVs are derived snapshots unless a documented workflow says otherwise.
- `data/raw/workouts/`: normalized per-workout source files for future ingestion.
- `R/`: project-local R modules for loading, validation, summaries, and plots. Keep these functions useful and testable, but do not optimize them as a public package interface.
- `tests/testthat/`: regression tests for data rules, summary behavior, and plot objects.
- `renv.lock`: dependency lockfile for local and CI reproducibility.
- `DESCRIPTION`, `NAMESPACE`, `man/`, and other package-era files may remain during the transition. Do not add new package-only workflows unless the user asks for them.

## Design Direction

- Aim the repo at a static Quarto dashboard on GitHub Pages, not a reusable R package.
- Keep R functions as small-interface modules that hide data parsing, validation, summary, or plotting details from the dashboard.
- Keep source data, derived data, dashboard source, and generated site output separate.
- Make CI/CD render from committed source data when possible. Avoid checking in rendered site output unless the selected Pages strategy requires a committed output directory such as `docs/`.
- When removing R package tooling, remove the replaced package artifact and update the affected commands or docs in the same commit.

## Data Rules

- Preserve exact Garmin exercise names. Treat `movement_group` as organization, not mechanical equivalence.
- Compute volume as `reps * weight_lb`.
- Do not infer missing warm-up sets, hidden values, or missing Garmin fields.
- New daily data should append normalized set-level records, then let summaries and dashboard output regenerate.
- Validate before rendering when touching ingestion, processed data, summaries, or plot logic.

## Dependencies

- Prefer existing R dependencies and packages already present in `renv.lock`.
- Add new R package dependencies only when they remove meaningful complexity or provide a clear charting, data, testing, or publishing capability.
- Prefer the tidyverse packages already in use over adjacent packages for small conveniences.
- When adding an R dependency, update `renv.lock`, explain the value of the dependency in the commit or PR notes, and verify the dashboard still renders.
- Quarto is an external CLI. Do not add it as an R package dependency.

## Commands

Run commands from the repository root unless noted otherwise.

- Restore dependencies: `Rscript -e "renv::restore()"`
- Run tests while the package-era structure remains: `Rscript -e "devtools::test()"`
- Render the dashboard: `quarto render dashboard`
- Avoid relying on `devtools::document()` or `R CMD check` for routine dashboard work unless package artifacts are intentionally changed.

## Commit Discipline

- Keep commits logical and small. Separate docs, data, analysis logic, dashboard rendering, CI wiring, and package-to-dashboard migration when they can be reviewed separately.
- Use Conventional Commits 1.0.0 format: `<type>[optional scope]: <description>`.
- Common types for this repo: `feat`, `fix`, `docs`, `test`, `refactor`, `ci`, and `chore`.
- Use `!` and a `BREAKING CHANGE:` footer for incompatible behavior or data contract changes.
- Do not mix generated output cleanup with functional changes unless the cleanup is required by that change.

## Generated Files

- Do not commit `dashboard/_site/`, `dashboard/.quarto/`, `check/`, `*.tar.gz`, or `*.Rcheck/` unless the publishing strategy changes.
- Reference plots in `inst/reference-plots/` are archival. Do not update them as dashboard render artifacts.
- If Pages publishing moves to a committed `docs/` directory, document that choice and adjust ignores in the same commit.

## Documentation Style

- Keep docs concise and factual. Prefer commands and invariants over long explanations.
- Update `README.md` or this file when paths, commands, deployment workflow, or the data contract changes.
- Use ASCII in repo docs unless quoting an external name that requires Unicode.
- Avoid broad claims about training progress or fitness trends unless they are backed by committed data.
