# Raw workout data

This directory is the repo-relative local-only raw-workout inbox for Garmin Splits CSV imports.

Use Garmin Connect **Export Splits to CSV** as the primary daily source format. Save each exported CSV here with this filename convention:

```text
YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv
```

Example:

```text
2026-08-22-garmin-splits-24097428247.csv
```

The leading date is the workout date. The trailing Garmin activity id is the stable activity identifier and importer dedupe key. Do not rely on date alone, because multiple workouts can happen on one day.

Splits CSV files provide set-level source values such as set number, exercise name, time, rest, reps, weight, and Garmin-reported volume. The export does not include a workout name, so the importer sets `workout_name` to `Garmin Strength YYYY-MM-DD (<garmin-activity-id>)` until the maintainer curates `workout_name` in `data/processed/lifting_sets.csv` before committing processed data.

Saved Garmin Connect HTML or HTM pages, FIT files, ZIP exports, and other raw workout artifacts are non-primary local-only source artifacts. They can contain location, device, profile, or physiology metadata that the public dashboard does not need.

Repository policy ignores raw files under this path and commits only this README. Do not commit raw Garmin exports here unless a maintainer intentionally creates a reduced, privacy-reviewed fixture for tests.

Daily updates should use the single command wrapper from the repository root:

```bash
Rscript scripts/update-workouts.R --check
Rscript scripts/update-workouts.R --write
```

The command runs the importer, full test suite, and dashboard render in order. In check mode it does not change processed data. In write mode it prints `git status --short` after all checks pass. Add one or more CSV paths after the mode to process only those local files. Leave raw source files local.
