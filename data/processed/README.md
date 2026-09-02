# Processed data

lifting_sets.csv is the canonical longitudinal set-level table used by tests and the dashboard. It keeps one row per recorded set, preserves Garmin source names in exercise_raw, stores canonical exercise, movement_group, and equipment_type values from exercise_mapping.csv, and stores setup-specific exercise_variant values when recorded weights are not comparable across machines or configurations. workouts.csv stores one row per activity with activity_id, day, date, date_source, and workout_name; the same workout fields remain duplicated in lifting_sets.csv for compatibility.
exercise_setups.csv is a reviewed lookup keyed by activity_id and exercise_raw. Use it when Garmin offers the same source exercise name for multiple setups, such as single-pulley and double-pulley rows.

Derived summaries, charts, and dashboard tables are recalculated from this file rather than committed as separate CSV snapshots. Raw Garmin exports belong under `data/raw/workouts/` for local-only ingestion work, not in this directory.

Garmin Connect Splits CSV is the selected ingestion source. Before normalization, required workout date and stable activity id metadata comes from the ignored raw filename:

```text
YYYY-MM-DD-garmin-splits-<garmin-activity-id>.csv
```

The importer should use the activity id as the dedupe key, append one workout metadata row plus normalized set rows, set missing workout names to Garmin Strength YYYY-MM-DD (<garmin-activity-id>), calculate canonical volume as reps * weight_lb, preserve exercise_raw, apply reviewed setup variants from exercise_setups.csv, and require any new Garmin exercise names to be mapped in exercise_mapping.csv before processed data is committed. Validation checks that workout metadata and setup assignments match the duplicated set-level fields.
