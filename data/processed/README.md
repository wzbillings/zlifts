# Processed data

`lifting_sets.csv` is the canonical longitudinal set-level table used by tests and the dashboard. It keeps one row per recorded set, preserves Garmin source names in `exercise_raw`, and stores canonical `exercise`, `movement_group`, and `equipment_type` values from `exercise_mapping.csv`.

Derived summaries, charts, and dashboard tables are recalculated from this file rather than committed as separate CSV snapshots. Raw Garmin exports belong under `data/raw/workouts/` for local-only ingestion work, not in this directory.
