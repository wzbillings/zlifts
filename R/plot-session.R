#' Plot total lifting volume by session
#'
#' @param session_summary Session-level summary data from summarize_sessions().
#' @param discrete_threshold Use discrete date columns up to this number of
#'   sessions; beyond that, use a date axis for readability.
#'
#' @return A ggplot object.
plot_session_volume <- function(session_summary, discrete_threshold = 12) {
  check_required_columns(
    session_summary,
    c("date", "total_volume_lb")
  )

  session_summary <- dplyr::arrange(session_summary, .data$date)

  if (nrow(session_summary) <= discrete_threshold) {
    plot_data <- dplyr::mutate(session_summary, date_label = format(.data$date, "%b %d"))
    p <- ggplot2::ggplot(
      plot_data,
      ggplot2::aes(x = stats::reorder(.data$date_label, .data$date), y = .data$total_volume_lb)
    ) +
      ggplot2::labs(x = NULL)
  } else {
    p <- ggplot2::ggplot(
      session_summary,
      ggplot2::aes(x = .data$date, y = .data$total_volume_lb)
    ) +
      ggplot2::scale_x_date(date_breaks = "1 month", date_labels = "%b %Y") +
      ggplot2::labs(x = NULL)
  }

  p +
    ggplot2::geom_col(width = 0.65, fill = "#3d6f70") +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::comma(.data$total_volume_lb)),
      vjust = -0.5,
      size = 3,
      na.rm = TRUE
    ) +
    ggplot2::scale_y_continuous(labels = scales::comma, expand = ggplot2::expansion(mult = c(0, 0.08))) +
    ggplot2::labs(
      y = "Total volume (lb)",
      title = "Total workout volume"
    ) +
    lifting_plot_theme() +
    ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
}

