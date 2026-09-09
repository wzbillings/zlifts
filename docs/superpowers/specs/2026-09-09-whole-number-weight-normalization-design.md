# Whole-number weight normalization design

## Goal

Treat every fractional Garmin lifting weight as a watch-entry typo. Processed
weights must be whole pounds, truncated toward zero, and processed volume must
use the normalized weight.

## Import behavior

The Garmin Splits importer will parse the source weight and volume before
normalization so malformed source values still fail clearly. It will then:

1. Truncate each non-missing weight toward zero.
2. Calculate `volume_lb` as `reps * weight_lb` using the truncated weight.
3. Set `garmin_volume_lb` to the same normalized calculation when the source
   Garmin volume is present; keep it missing when Garmin omitted the field.
4. Keep `volume_matches_garmin` as the integrity check against Garmin's original
   values before normalization. A Garmin volume consistent with its source reps
   and source weight remains a match; an unrelated source mismatch remains a
   failure.

The local raw CSV remains the exact source record. Processed data contains the
normalized analytical values.

## Validation

`validate_lifting_data()` will add a check requiring every populated
`weight_lb` value to be a whole number. Existing volume checks continue to
require normalized volume fields to agree with `reps * weight_lb`, while the
stored source-integrity flag continues to expose unrelated Garmin volume
mismatches.

## Existing data migration

Apply the same truncation and volume recalculation to all committed processed
sets. Preserve missing values and existing source-integrity flags. This includes
changing the September 9, 2026 Leg Press entry from 210.5 lb to 210 lb and its
processed volumes from 3,157.5 lb to 3,150 lb.

## Tests

Importer tests will cover fractional weights, whole weights, missing weights,
normalized processed volumes, and preservation of unrelated Garmin volume
mismatch detection. Validation tests will cover the new whole-number invariant.
The full test suite and Quarto dashboard render must pass after the migration.
