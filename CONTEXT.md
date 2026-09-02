# ZLifts Analysis

ZLifts tracks normalized Garmin strength-training data for a static dashboard. The language below separates source labels, analytical labels, and setup variants so recorded loads are compared only within compatible contexts.

## Language

**Exercise Raw**:
The exact Garmin exercise name recorded in the source export.
_Avoid_: Source exercise, raw label

**Exercise**:
The canonical analytical movement name used for summaries and display. It is load-comparable only together with exercise_variant and equipment_type.
_Avoid_: Garmin exercise name

**Exercise Variant**:
A setup-specific qualifier for the same exercise when recorded weights are not comparable across machines or configurations, such as single-pulley versus double-pulley rows.
_Avoid_: Machine type, movement group

**Movement Group**:
A broad organization bucket for related work. It is not a promise that recorded weights are mechanically comparable.
_Avoid_: Exercise variant, load group

**Equipment Type**:
The broad equipment or mode distinction, such as machine, dumbbell, barbell, cable, band, or bodyweight.
_Avoid_: Exercise setup

**Exercise Setup Assignment**:
A curated activity-level assignment that maps an activity_id and exercise_raw pair to an exercise_variant when Garmin labels are too coarse.
_Avoid_: Data correction, inferred workout detail
