# Raw workout data

This directory is reserved for local-only Garmin source exports used during future ingestion work. Saved Garmin Connect HTML or HTM pages, FIT files, ZIP exports, and other raw workout artifacts can contain location, device, profile, or physiology metadata that the public dashboard does not need.

Repository policy ignores raw files under this path and commits only this README. Do not commit raw Garmin exports here unless a maintainer intentionally creates a reduced, privacy-reviewed fixture for tests.

Daily updates currently happen by committing normalized rows to `data/processed/lifting_sets.csv`. Future ingestion should parse local files from this directory, validate them, append canonical set rows, and leave raw source files local.
