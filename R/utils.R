required_lifting_columns <- function() {
  c(
    "activity_id", "day", "date", "workout_name", "set_number",
    "exercise_raw", "exercise", "movement_group", "set_type",
    "time_seconds", "rest_seconds", "reps", "weight_lb",
    "garmin_volume_lb", "volume_lb", "volume_matches_garmin"
  )
}

check_required_columns <- function(data, columns = required_lifting_columns()) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0) {
    rlang::abort(
      c(
        "Missing required column(s) in lifting data.",
        x = paste("Missing required column(s):", paste(missing, collapse = ", "))
      ),
      class = "garminlifting_missing_columns"
    )
  }
  invisible(data)
}

parse_logical_text <- function(x) {
  if (is.logical(x)) {
    return(x)
  }

  lower <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    lower %in% c("true", "t", "1", "yes", "y") ~ TRUE,
    lower %in% c("false", "f", "0", "no", "n") ~ FALSE,
    is.na(x) | lower == "" ~ NA,
    TRUE ~ NA
  )
}

sum_or_na <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  sum(x, na.rm = TRUE)
}

max_or_na <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  max(x, na.rm = TRUE)
}

mean_or_na <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}

first_or_na <- function(x) {
  known <- x[!is.na(x) & trimws(as.character(x)) != ""]
  if (length(known) == 0) {
    return(NA_character_)
  }
  as.character(known[[1]])
}

set_volume <- function(data) {
  data$reps * data$weight_lb
}

check_row <- function(check, status, message, n = 0L) {
  data.frame(
    check = check,
    status = status,
    message = message,
    n = as.integer(n),
    stringsAsFactors = FALSE
  )
}

utils::globalVariables(c(".data"))
