# zlifts

`zlifts` is a personal Quarto dashboard project for longitudinal analysis of normalized Garmin strength-training data. The set-level file is the source of truth; summaries, plots, tests, and the dashboard are all calculated from that table through project-local R modules.

Live dashboard: <https://wzbillings.github.io/zlifts/>

## Data model

The canonical analytical dataset is `data/processed/lifting_sets.csv`. It has one row per recorded set. `exercise_raw` preserves Garmin's standardized source name, while `exercise`, `movement_group`, and `equipment_type` are populated from `data/processed/exercise_mapping.csv` for canonical analysis and display.

Volume is calculated as `reps * weight_lb`. Missing fields are preserved rather than inferred. In particular, warm-up sets are not inferred when `set_type` is missing.

## Public data policy

This public repository commits only normalized analysis-ready lifting data at `data/processed/lifting_sets.csv`. Derived summaries are regenerated from that file by project-local R functions and are not committed as canonical data.

Raw Garmin Connect HTML or HTM pages, FIT files, ZIP exports, and similar source artifacts are local-only by default. They can contain location, device, profile, or physiology metadata that the public dashboard does not need, so `.gitignore` blocks files under `data/raw/workouts/` except for that directory's README.

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

`data/raw/workouts/` is reserved for local-only Garmin source exports once an ingestion step exists. `data/processed/lifting_sets.csv` is the longitudinal source table used by the dashboard. R modules in `R/` are loaded with `scripts/source-analysis.R`; they are project code, not a package API. The original seed analysis script and PNG previews are archived in `archive/reference-plots/`; the dashboard does not read them.

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

## Future workout flow

Future ingestion is intentionally not implemented yet. Daily updates currently happen by committing normalized rows to `data/processed/lifting_sets.csv` and keeping `data/processed/exercise_mapping.csv` in sync when new Garmin names appear. Conceptually, new workouts should enter like this:

```text
local-only Garmin Splits CSV export
        ->
future ingestion pipeline
        ->
canonical set-level records
        ->
lifting_sets.csv
        ->
summaries + dashboard
```

When that ingestion layer is added, it should append normalized set-level records, require any new `exercise_raw` values to be added to the mapping, and let the existing project-local functions regenerate summaries and dashboard output. Raw Garmin source files should remain local unless a maintainer intentionally creates a reduced, privacy-reviewed test fixture.

## License

This project is licensed under the GNU Affero General Public License v3.0 only (`AGPL-3.0-only`). See `LICENSE` for the full terms.
