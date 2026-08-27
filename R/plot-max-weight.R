#' Plot maximum exercise weight over time
#'
#' @param exercise_summary Exercise-level summary data from
#'   summarize_exercises().
#' @param ncol Number of facet columns.
#'
#' @return A ggplot object.
#' @export
plot_exercise_max_weight <- function(exercise_summary, ncol = 3) {
  check_required_columns(
    exercise_summary,
    c("date", "exercise", "max_weight_lb")
  )

  ggplot2::ggplot(
    exercise_summary,
    ggplot2::aes(x = .data$date, y = .data$max_weight_lb, group = .data$exercise)
  ) +
    ggplot2::geom_line(linewidth = 0.7, colour = "#5b7f3a", na.rm = TRUE) +
    ggplot2::geom_point(size = 2.4, colour = "#34551f", na.rm = TRUE) +
    ggplot2::geom_text(
      ggplot2::aes(label = paste0(scales::comma(.data$max_weight_lb), " lb")),
      vjust = -0.7,
      size = 2.6,
      check_overlap = TRUE,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(ggplot2::vars(.data$exercise), scales = "free_y", ncol = ncol) +
    ggplot2::scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
    ggplot2::scale_y_continuous(labels = scales::comma) +
    ggplot2::labs(
      x = NULL,
      y = "Maximum recorded weight (lb)",
      title = "Maximum recorded weight by exercise over time",
      subtitle = "Exercise variants remain separate unless explicitly combined later"
    ) +
    lifting_plot_theme()
}

