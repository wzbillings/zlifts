# zlifts

`zlifts` is a personal Quarto dashboard project for longitudinal analysis of normalized Garmin strength-training data. The set-level file is the source of truth; summaries, plots, tests, and the dashboard are all calculated from that table.

## Data model

The canonical analytical dataset is `data/processed/lifting_sets.csv`. It has one row per recorded set and preserves Garmin's standardized `exercise` name exactly. `movement_group` is only an organizational grouping; loads from different exercise variants are not treated as mechanically equivalent unless a future analysis explicitly asks for that.

Volume is calculated as `reps * weight_lb`. Missing fields are preserved rather than inferred. In particular, warm-up sets are not inferred when `set_type` is missing.

## Directory structure

```text
zlifts/
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── README.md
├── zlifts.Rproj
├── R/
├── data/
│   ├── raw/
│   │   └── workouts/
│   └── processed/
├── dashboard/
├── tests/
│   └── testthat/
├── man/
├── inst/
│   └── reference-plots/
└── renv/
```

`data/raw/workouts/` is reserved for normalized per-workout inputs once an ingestion step exists. `data/processed/lifting_sets.csv` is the longitudinal source table used by the dashboard. The original seed analysis script and PNG previews are archived in `inst/reference-plots/`; the dashboard does not read them.

## Restore dependencies

From a fresh clone, install R and the Quarto CLI, then run:

```r
renv::restore()
```

The DESCRIPTION file stays limited to R runtime and test dependencies while the package-era structure remains. The renv lockfile also records development and dashboard tooling detected from the repository files. Quarto itself is an external CLI and is not listed as an R package dependency.

## Develop and test

```r
devtools::load_all()
devtools::test()
devtools::document()
devtools::check()
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

Open the rendered dashboard at `dashboard/_site/index.html`.

The dashboard has four sections: Overview, Exercise Progress, Set Performance, and Data / QA. It loads `data/processed/lifting_sets.csv`, runs project-local R functions, and renders ggplot2 figures directly from the data.

## Future workout flow

Future ingestion is intentionally not implemented yet. Conceptually, new workouts should enter like this:

```text
Garmin export/HTML
        ->
future ingestion pipeline
        ->
canonical set-level records
        ->
lifting_sets.csv
        ->
summaries + dashboard
```

When that ingestion layer is added, it should append normalized set-level records and let the existing project-local functions regenerate summaries and dashboard output.


