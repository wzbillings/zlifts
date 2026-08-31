# Processed data

`lifting_sets.csv` is the canonical longitudinal set-level table used by tests and the dashboard. It keeps one row per recorded set, preserves Garmin source names in `exercise_raw`, and stores canonical `exercise`, `movement_group`, and `equipment_type` values from `exercise_mapping.csv`. `workouts.csv` stores one row per activity with `activity_id`, `day`, `date`, `date_source`, and `workout_name`; the same workout fields remain duplicated in `lifting_sets.csv` for compatibility.

Derived summaries, charts, and dashboard tables are recalculated from this file rather than committed as separate CSV snapshots. Raw Garmin exports belong under `data/raw/workouts/` for local-only ingestion work, not in this directory.

Garmin Connect Splits CSV is the selected ingestion source. Before normalization, required workout date and stable activity id metadata comes from the ignored raw filename:

```text
YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv
```

The importer should use the activity id as the dedupe key, append one workout metadata row plus normalized set rows, set missing workout names to `Garmin Strength YYYY-MM-DD (<garmin-activity-id>)`, calculate canonical volume as `reps * weight_lb`, preserve `exercise_raw`, and require any new Garmin exercise names to be mapped in `exercise_mapping.csv` before processed data is committed. Validation checks that workout metadata matches the duplicated set-level workout fields.
