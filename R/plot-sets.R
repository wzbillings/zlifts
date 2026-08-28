#' Plot set-level load and repetitions
#'
#' @param sets A set-level tibble, usually from read_lifting_sets().
#' @param ncol Number of facet columns.
#'
#' @return A ggplot object.
plot_set_performance <- function(sets, ncol = 3) {
  check_required_columns(
    sets,
    c("date", "set_number", "exercise", "equipment_type", "weight_lb", "reps", "volume_lb")
  )

  sets <- dplyr::mutate(
    sets,
    exercise_label = exercise_display_name(.data$exercise, .data$equipment_type),
    hover_text = paste0(
      "Date: ", format_hover_date(.data$date),
      "<br>Exercise: ", .data$exercise,
      "<br>Type: ", format_equipment_type(.data$equipment_type),
      "<br>Set: ", format_hover_count(.data$set_number),
      "<br>Weight: ", format_hover_lb(.data$weight_lb),
      "<br>Reps: ", format_hover_count(.data$reps),
      "<br>Volume: ", format_hover_lb(.data$volume_lb)
    )
  )

  ggplot2::ggplot(
    sets,
    ggplot2::aes(x = .data$date, y = .data$weight_lb, text = .data$hover_text)
  ) +
    ggplot2::geom_point(
      ggplot2::aes(size = .data$reps),
      position = ggplot2::position_jitter(width = 0.18, height = 0),
      alpha = 0.68,
      colour = "#6f4e7c",
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(ggplot2::vars(.data$exercise_label), scales = "free_y", ncol = ncol) +
    ggplot2::scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
    ggplot2::scale_y_continuous(labels = scales::comma) +
    ggplot2::scale_size_continuous(range = c(2, 6), breaks = c(5, 10, 15)) +
    ggplot2::labs(
      x = NULL,
      y = "Recorded weight (lb)",
      size = "Reps",
      title = "Set-level load and repetitions"
    ) +
    lifting_plot_theme()
}
