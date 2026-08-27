# Garmin strength-training longitudinal analysis
# Generated from lifting_sets.csv extracted from the three saved Garmin HTML files.
# Requires: tidyverse, scales

library(tidyverse)
library(scales)

sets <- read_csv("lifting_sets.csv", show_col_types = FALSE) |>
  mutate(date = as.Date(date))

exercise_summary <- sets |>
  group_by(activity_id, day, date, exercise, movement_group) |>
  summarise(
    sets = n(),
    total_reps = sum(reps, na.rm = TRUE),
    total_volume_lb = sum(reps * weight_lb, na.rm = TRUE),
    max_weight_lb = max(weight_lb, na.rm = TRUE),
    mean_weight_lb = mean(weight_lb, na.rm = TRUE),
    max_set_volume_lb = max(reps * weight_lb, na.rm = TRUE),
    .groups = "drop"
  )

# A) Total training volume for each exact Garmin exercise over time.
# Free y-scales are deliberate: a 200-lb calf raise and a 10-lb curl should
# not force each other onto an unreadable common vertical scale.
p_volume <- ggplot(exercise_summary,
                   aes(x = date, y = total_volume_lb, group = exercise)) +
  geom_line(linewidth = 0.7, na.rm = TRUE) +
  geom_point(size = 2.4) +
  geom_text(aes(label = comma(total_volume_lb)),
            vjust = -0.7, size = 2.6, check_overlap = TRUE) +
  facet_wrap(vars(exercise), scales = "free_y", ncol = 3) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  scale_y_continuous(labels = comma) +
  labs(
    x = NULL,
    y = "Total volume (lb)",
    title = "Exercise training volume over time",
    subtitle = "Exact Garmin exercise names; volume = sum(reps x recorded weight) within workout",
    caption = "Dates for these first three sessions were inferred from the saved-page relative weekday labels."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

# B) Maximum recorded working weight for each exact exercise over time.
p_max_weight <- ggplot(exercise_summary,
                       aes(x = date, y = max_weight_lb, group = exercise)) +
  geom_line(linewidth = 0.7, na.rm = TRUE) +
  geom_point(size = 2.4) +
  geom_text(aes(label = paste0(max_weight_lb, " lb")),
            vjust = -0.7, size = 2.6, check_overlap = TRUE) +
  facet_wrap(vars(exercise), scales = "free_y", ncol = 3) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  labs(
    x = NULL,
    y = "Maximum recorded weight (lb)",
    title = "Maximum recorded weight by exercise over time",
    subtitle = "Different exercise variants are not merged because machine/cable/dumbbell loads are not automatically comparable",
    caption = "Dates for these first three sessions were inferred from the saved-page relative weekday labels."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

# C) Set-level load and reps. Point size represents repetitions.
# position_jitter is used only to separate multiple sets recorded on one date.
p_sets <- ggplot(sets, aes(x = date, y = weight_lb)) +
  geom_point(aes(size = reps),
             position = position_jitter(width = 0.18, height = 0),
             alpha = 0.65) +
  facet_wrap(vars(exercise), scales = "free_y", ncol = 3) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  scale_size_continuous(range = c(2, 6), breaks = c(5, 10, 15)) +
  labs(
    x = NULL,
    y = "Recorded weight (lb)",
    size = "Reps",
    title = "Set-level load and repetitions"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

# D) Whole-workout volume. With only three discrete sessions, bars are more
# honest than implying a smooth trend line.
session_summary <- sets |>
  group_by(activity_id, day, date) |>
  summarise(
    total_sets = n(),
    total_reps = sum(reps),
    total_volume_lb = sum(reps * weight_lb),
    .groups = "drop"
  )

p_session_volume <- ggplot(session_summary,
                           aes(x = factor(date), y = total_volume_lb)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = comma(total_volume_lb)), vjust = -0.5) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, .08))) +
  labs(
    x = NULL,
    y = "Total volume (lb)",
    title = "Total workout volume"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank())

# Save outputs
ggsave("01_exercise_volume_over_time_ggplot.png", p_volume,
       width = 14, height = 13, dpi = 300)
ggsave("02_exercise_max_weight_over_time_ggplot.png", p_max_weight,
       width = 14, height = 13, dpi = 300)
ggsave("03_set_load_and_reps_ggplot.png", p_sets,
       width = 14, height = 13, dpi = 300)
ggsave("04_total_workout_volume_ggplot.png", p_session_volume,
       width = 8, height = 5, dpi = 300)

# Optional: use movement_group for coverage/organization, but do NOT treat
# weights from different variants as mechanically interchangeable.
movement_coverage <- sets |>
  distinct(date, movement_group, exercise) |>
  arrange(movement_group, date)

print(p_volume)
print(p_max_weight)
print(p_sets)
print(p_session_volume)
