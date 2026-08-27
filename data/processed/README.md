# Processed data

`lifting_sets.csv` is the canonical longitudinal set-level table used by tests and the dashboard. It keeps one row per recorded set, preserves exact Garmin exercise names, and stores normalized analysis-ready fields.

Derived summaries, charts, and dashboard tables are recalculated from this file rather than committed as separate CSV snapshots. Raw Garmin exports belong under `data/raw/workouts/` for local-only ingestion work, not in this directory.
