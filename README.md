# zlifts

`zlifts` is a personal Quarto dashboard project for longitudinal analysis of normalized Garmin strength-training data. The set-level file is the source of truth; summaries, plots, tests, and the dashboard are all calculated from that table through project-local R modules.

Live dashboard: <https://wzbillings.github.io/zlifts/>

## Data model

The canonical analytical dataset is `data/processed/lifting_sets.csv`. It has one row per recorded set. `exercise_raw` preserves Garmin's standardized source name, while `exercise`, `movement_group`, and `equipment_type` are populated from `data/processed/exercise_mapping.csv` for canonical analysis and display.

Volume is calculated as `reps * weight_lb`. Missing fields are preserved rather than inferred. In particular, warm-up sets are not inferred when `set_type` is missing.

## Public data policy

This public repository commits only normalized analysis-ready lifting data at `data/processed/lifting_sets.csv`. Derived summaries are regenerated from that file by project-local R functions and are not committed as canonical data.

Raw Garmin Connect Splits CSV exports are the selected daily ingestion source, but they are still local-only by default. Saved HTML or HTM pages, FIT files, ZIP exports, and similar non-primary source artifacts can contain location, device, profile, or physiology metadata that the public dashboard does not need, so `.gitignore` blocks files under `data/raw/workouts/` except for that directory's README.

The dashboard and GitHub Pages workflow must read committed processed data only. Raw Garmin exports are not dashboard inputs and must not be copied into rendered output.

## Directory structure

```text
zlifts/
|-- LICENSE
|-- README.md
|-- zlifts.Rproj
|-- R/
|-- scripts/
|-- data/
|   |-- raw/
|   |   `-- workouts/
|   `-- processed/
|-- dashboard/
|-- tests/
|   `-- testthat/
|-- tools/
|-- archive/
|   `-- reference-plots/
`-- renv/
```

`data/raw/workouts/` is reserved for local-only Garmin Splits CSV exports and other private Garmin source artifacts used while developing ingestion. `data/processed/lifting_sets.csv` is the longitudinal source table used by the dashboard. R modules in `R/` are loaded with `scripts/source-analysis.R`; they are project code, not a package API. The original seed analysis script and PNG previews are archived in `archive/reference-plots/`; the dashboard does not read them.

## Restore dependencies

From a fresh clone, install R and the Quarto CLI, then run:

```r
renv::restore()
```

The renv lockfile records R packages used by the analysis code, tests, and dashboard. Quarto itself is an external CLI and is not listed as an R package dependency.

## Develop and test

```bash
Rscript tests/testthat.R
```

The regression tests assert that the seed dataset has 75 set records, three activities, and the validated chronological session totals:

```text
sets:   23, 26, 26
reps:   336, 348, 380
volume: 18,805 lb; 25,665 lb; 33,325 lb
```

## Render the dashboard

From the repository root:

```bash
quarto render dashboard
```

Open the rendered dashboard at `dashboard/_site/index.html`, or use the published GitHub Pages site after the workflow runs.

The dashboard has five sections: Overview, Progress Highlights, Exercise Progress, Set Performance, and Data / QA. It loads `data/processed/lifting_sets.csv`, runs project-local R functions, and renders interactive figures directly from the data.

## Publish to GitHub Pages

The `.github/workflows/publish-dashboard.yml` workflow restores R packages from `renv.lock`, runs tests, renders `dashboard/_site`, uploads that directory as a GitHub Pages artifact, and deploys it. GitHub Pages is configured to use "GitHub Actions" as the source.

## Workout import flow

Garmin Splits ingestion is implemented through `scripts/ingest-workouts.R`. Daily updates happen by placing local raw exports in `data/raw/workouts/`, checking them, writing normalized rows to `data/processed/lifting_sets.csv`, and keeping `data/processed/exercise_mapping.csv` in sync when new Garmin names appear. New workouts enter like this:

```text
local-only Garmin Splits CSV export
        ->
scripts/update-workouts.R --check, then scripts/update-workouts.R --write
        ->
canonical set-level records
        ->
lifting_sets.csv
        ->
summaries + dashboard
```

Place daily Garmin Connect "Export Splits to CSV" files in `data/raw/workouts/` using this filename convention:

```text
YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv
```

The leading date is the workout date. The trailing Garmin activity id is the stable activity identifier and importer dedupe key; do not rely on date alone. The Splits CSV supplies set number, exercise name, time, rest, reps, weight, and Garmin-reported volume. Splits CSV exports do not carry a workout name, so the importer sets `workout_name` to `Garmin Strength YYYY-MM-DD (<garmin-activity-id>)` until the maintainer curates `workout_name` in the processed data before commit.
Run the daily update command from the repository root. It first invokes the existing importer, then the regression suite and dashboard render. Check mode never changes processed data; write mode prints the resulting Git status after all verification succeeds.

```bash
Rscript scripts/update-workouts.R --check
Rscript scripts/update-workouts.R --write
```

Pass one or more explicit local CSV paths to update only those exports:

```bash
Rscript scripts/update-workouts.R --check data/raw/workouts/2026-08-22-garmin-splits-24097428247.csv
Rscript scripts/update-workouts.R --write data/raw/workouts/2026-08-22-garmin-splits-24097428247.csv
```



The importer appends normalized set-level records, requires any new `exercise_raw` values to be added to the mapping, and lets the existing project-local functions regenerate summaries and dashboard output. Raw Garmin source files should remain local unless a maintainer intentionally creates a reduced, privacy-reviewed test fixture.

When check mode finds an unmapped Garmin exercise name, it prints copy-ready CSV rows but does not modify `data/processed/exercise_mapping.csv`. Review each suggested row before adding it: keep the suggested `exercise_raw` exactly as Garmin exported it, replace the conservative `exercise` and `movement_group` placeholders with the appropriate canonical labels, and confirm `equipment_type`. Suggestions default to `machine`; explicit dumbbell, barbell, cable, band, and bodyweight labels are detected, but existing reviewed quirks remain authoritative. After updating the mapping manually, rerun `--check`; use `--write` only after the importer, tests, and render complete successfully.

## License

This project is licensed under the GNU Affero General Public License v3.0 only (`AGPL-3.0-only`). See `LICENSE` for the full terms.
