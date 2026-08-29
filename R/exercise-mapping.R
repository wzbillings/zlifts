default_exercise_mapping_path <- function(path = NULL) {
  if (!is.null(path)) {
    return(path)
  }

  if (exists("find_project_root", mode = "function")) {
    return(file.path(find_project_root(), "data", "processed", "exercise_mapping.csv"))
  }

  file.path("data", "processed", "exercise_mapping.csv")
}

required_exercise_mapping_columns <- function() {
  c("exercise_raw", "exercise", "movement_group", "equipment_type", "review_status", "notes")
}

check_exercise_raw_column <- function(data) {
  if (!"exercise_raw" %in% names(data)) {
    rlang::abort(
      c(
        "Missing required column(s) in lifting data.",
        x = paste("Missing required column(s):", "exercise_raw")
      ),
      class = "zlifts_missing_columns"
    )
  }

  invisible(data)
}

check_exercise_mapping <- function(mapping) {
  missing <- setdiff(required_exercise_mapping_columns(), names(mapping))
  if (length(missing) > 0) {
    rlang::abort(
      c(
        "Missing required column(s) in exercise mapping.",
        x = paste("Missing required column(s):", paste(missing, collapse = ", "))
      ),
      class = "zlifts_missing_columns"
    )
  }

  blank_raw <- is.na(mapping[["exercise_raw"]]) | trimws(mapping[["exercise_raw"]]) == ""
  blank_mapped <- is.na(mapping[["exercise"]]) | trimws(mapping[["exercise"]]) == "" |
    is.na(mapping[["movement_group"]]) | trimws(mapping[["movement_group"]]) == "" |
    is.na(mapping[["equipment_type"]]) | trimws(mapping[["equipment_type"]]) == ""
  duplicate_raw <- duplicated(mapping[["exercise_raw"]]) | duplicated(mapping[["exercise_raw"]], fromLast = TRUE)

  if (any(blank_raw)) {
    rlang::abort(
      "Exercise mapping must not contain blank Garmin exercise names.",
      class = "zlifts_bad_exercise_mapping"
    )
  }

  if (any(blank_mapped)) {
    rlang::abort(
      "Exercise mapping must not contain blank mapped exercise fields.",
      class = "zlifts_bad_exercise_mapping"
    )
  }

  if (any(duplicate_raw)) {
    duplicated_names <- unique(mapping[["exercise_raw"]][duplicate_raw])
    rlang::abort(
      c(
        "Exercise mapping has duplicate Garmin exercise names.",
        x = paste("Duplicate Garmin exercise name(s):", paste(duplicated_names, collapse = ", "))
      ),
      class = "zlifts_bad_exercise_mapping"
    )
  }

  invisible(mapping)
}

read_exercise_mapping <- function(path = NULL) {
  path <- default_exercise_mapping_path(path)
  if (!file.exists(path)) {
    rlang::abort(
      c(
        "Cannot find exercise mapping.",
        x = paste("Path does not exist:", path)
      ),
      class = "zlifts_missing_file"
    )
  }

  mapping <- readr::read_csv(
    path,
    col_types = readr::cols(
      exercise_raw = readr::col_character(),
      exercise = readr::col_character(),
      movement_group = readr::col_character(),
      equipment_type = readr::col_character(),
      review_status = readr::col_character(),
      notes = readr::col_character()
    ),
    show_col_types = FALSE
  )

  check_exercise_mapping(mapping)
  mapping
}

resolve_exercise_mapping <- function(mapping = NULL) {
  if (is.null(mapping)) {
    return(read_exercise_mapping())
  }

  if (is.character(mapping) && length(mapping) == 1) {
    return(read_exercise_mapping(mapping))
  }

  check_exercise_mapping(mapping)
  mapping
}

attach_exercise_mapping_fields <- function(sets, mapping = NULL) {
  check_exercise_raw_column(sets)
  mapping <- resolve_exercise_mapping(mapping)

  mapping_for_join <- dplyr::transmute(
    mapping,
    exercise_raw = .data$exercise_raw,
    .mapped_exercise = .data$exercise,
    .mapped_movement_group = .data$movement_group,
    .mapped_equipment_type = .data$equipment_type
  )

  dplyr::left_join(sets, mapping_for_join, by = "exercise_raw")
}

unmapped_exercise_names <- function(sets, mapping = NULL) {
  mapped <- attach_exercise_mapping_fields(sets, mapping)

  raw_names <- unique(mapped[["exercise_raw"]][is.na(mapped[[".mapped_exercise"]])])
  raw_names <- raw_names[!is.na(raw_names) & trimws(raw_names) != ""]
  raw_names
}

suggested_equipment_type <- function(exercise_raw) {
  name <- tolower(exercise_raw)

  if (grepl("dumbbell", name, fixed = TRUE)) {
    return("dumbbell")
  }
  if (grepl("barbell", name, fixed = TRUE)) {
    return("barbell")
  }
  if (grepl("cable", name, fixed = TRUE)) {
    return("cable")
  }
  if (grepl("band", name, fixed = TRUE)) {
    return("band")
  }
  if (grepl("bodyweight", name, fixed = TRUE) || grepl("body weight", name, fixed = TRUE)) {
    return("bodyweight")
  }

  "machine"
}

suggest_exercise_mapping <- function(exercise_raw) {
  exercise_raw <- unique(as.character(exercise_raw))
  exercise_raw <- exercise_raw[!is.na(exercise_raw) & trimws(exercise_raw) != ""]

  tibble::tibble(
    exercise_raw = exercise_raw,
    exercise = exercise_raw,
    movement_group = exercise_raw,
    equipment_type = vapply(exercise_raw, suggested_equipment_type, character(1)),
    review_status = "inferred",
    notes = "Review suggested mapping before adding."
  )
}

format_exercise_mapping_suggestions <- function(exercise_raw) {
  csv <- readr::format_csv(suggest_exercise_mapping(exercise_raw), na = "")
  lines <- strsplit(csv, "\n", fixed = TRUE)[[1]]

  paste(lines[-1], collapse = "\n")
}

abort_unmapped_exercises <- function(exercise_raw, mapping_path = NULL) {
  unmapped <- unique(as.character(exercise_raw))
  unmapped <- unmapped[!is.na(unmapped) & trimws(unmapped) != ""]
  location <- if (is.null(mapping_path)) {
    "Review and add the suggested row(s) to exercise_mapping.csv:"
  } else {
    paste0("Review and add the suggested row(s) to ", mapping_path, ":")
  }

  rlang::abort(
    c(
      "Unmapped Garmin exercise name.",
      x = paste("Unmapped Garmin exercise name(s):", paste(unmapped, collapse = ", ")),
      i = paste(location, format_exercise_mapping_suggestions(unmapped), sep = "\n")
    ),
    class = "zlifts_unmapped_exercises"
  )
}

apply_exercise_mapping <- function(sets, mapping = NULL) {
  mapped <- attach_exercise_mapping_fields(sets, mapping)
  unmapped <- unique(mapped[["exercise_raw"]][is.na(mapped[[".mapped_exercise"]])])
  unmapped <- unmapped[!is.na(unmapped) & trimws(unmapped) != ""]

  if (length(unmapped) > 0) {
    abort_unmapped_exercises(unmapped)
  }

  mapped <- dplyr::mutate(
    mapped,
    exercise = .data[[".mapped_exercise"]],
    movement_group = .data[[".mapped_movement_group"]],
    equipment_type = .data[[".mapped_equipment_type"]]
  )

  dplyr::select(mapped, -dplyr::all_of(c(".mapped_exercise", ".mapped_movement_group", ".mapped_equipment_type")))
}
