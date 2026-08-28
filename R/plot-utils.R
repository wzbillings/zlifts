# Shared ggplot theme for static plots before Quarto converts them to widgets.
lifting_plot_theme <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title.position = "plot",
      legend.position = "bottom"
    )
}

# Convert a ggplot to a self-contained Plotly widget for the static dashboard.
interactive_lifting_plot <- function(plot, tooltip = "text") {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    rlang::abort(
      c(
        "Plotly is required for interactive dashboard plots.",
        i = "Install project dependencies with `renv::restore()`."
      ),
      class = "zlifts_missing_plotly"
    )
  }

  plotly::ggplotly(plot, tooltip = tooltip) |>
    plotly::config(displaylogo = FALSE)
}

format_hover_date <- function(x) {
  format(as.Date(x), "%Y-%m-%d")
}

format_hover_lb <- function(x) {
  dplyr::if_else(
    is.na(x),
    "Missing",
    paste0(scales::comma(x), " lb")
  )
}

format_hover_count <- function(x) {
  dplyr::if_else(
    is.na(x),
    "Missing",
    scales::comma(x)
  )
}

exercise_display_name <- function(exercise, equipment_type) {
  label <- as.character(exercise)
  type <- tolower(trimws(as.character(equipment_type)))
  show_type <- !is.na(type) & type != "" & type != "machine"
  label[show_type] <- paste0(label[show_type], " (", type[show_type], ")")
  label
}

format_equipment_type <- function(x) {
  x <- trimws(as.character(x))
  known <- is.na(x) == FALSE
  missing <- is.na(x)
  missing[known] <- x[known] == ""
  x[missing] <- "unknown"
  tools::toTitleCase(x)
}
