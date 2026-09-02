#' Plot exercise volume over time
#'
#' @param exercise_summary Exercise-level summary data from
#'   summarize_exercises().
#' @param ncol Number of facet columns.
#'
#' @return A ggplot object.
plot_exercise_volume <- function(exercise_summary, ncol = 3) {
  check_required_columns(
    exercise_summary,
    c('date', 'exercise', 'exercise_variant', 'equipment_type', 'sets', 'total_reps', 'total_volume_lb')
  )

  exercise_summary <- dplyr::mutate(
    exercise_summary,
    exercise_label = exercise_display_name(.data[['exercise']], .data[['equipment_type']], .data[['exercise_variant']]),
    hover_text = paste0(
      "Date: ", format_hover_date(.data$date),
      "<br>Exercise: ", .data$exercise,
      "<br>Type: ", format_equipment_type(.data$equipment_type),
      "<br>Sets: ", format_hover_count(.data$sets),
      "<br>Reps: ", format_hover_count(.data$total_reps),
      "<br>Total volume: ", format_hover_lb(.data$total_volume_lb)
    )
  )

  ggplot2::ggplot(
    exercise_summary,
    ggplot2::aes(
      x = .data$date,
      y = .data$total_volume_lb,
      group = .data$exercise_label,
      text = .data$hover_text
    )
  ) +
    ggplot2::geom_line(linewidth = 0.7, colour = "#3b6ea8", na.rm = TRUE) +
    ggplot2::geom_point(size = 2.4, colour = "#214f7a", na.rm = TRUE) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::comma(.data$total_volume_lb)),
      vjust = -0.7,
      size = 2.6,
      check_overlap = TRUE,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(ggplot2::vars(.data$exercise_label), scales = "free_y", ncol = ncol) +
    ggplot2::scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
    ggplot2::scale_y_continuous(labels = scales::comma) +
    ggplot2::labs(
      x = NULL,
      y = "Total volume (lb)",
      title = "Exercise training volume over time",
      subtitle = "Canonical exercise names with equipment variants; volume is reps times recorded weight within each workout"
    ) +
    lifting_plot_theme()
}
