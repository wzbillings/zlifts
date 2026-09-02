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
  c("exercise_raw", "exercise", "exercise_variant", "movement_group", "equipment_type", "review_status", "notes")
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

coalesce_optional_text <- function(preferred, fallback) {
  preferred <- trimws(as.character(preferred))
  fallback <- trimws(as.character(fallback))
  preferred[is.na(preferred) | preferred == ''] <- NA_character_
  fallback[is.na(fallback) | fallback == ''] <- NA_character_
  dplyr::if_else(!is.na(preferred), preferred, fallback)
}

normalize_exercise_mapping <- function(mapping) {
  if (!'exercise_variant' %in% names(mapping)) {
    mapping[['exercise_variant']] <- NA_character_
  }
  mapping
}

check_exercise_mapping <- function(mapping) {
  mapping <- normalize_exercise_mapping(mapping)
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
      exercise_variant = readr::col_character(),
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

  mapping <- normalize_exercise_mapping(mapping)
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
    .mapped_exercise_variant = .data$exercise_variant,
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
    exercise_variant = NA_character_,
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
  if (!'exercise_variant' %in% names(sets)) {
    sets[['exercise_variant']] <- NA_character_
  }

  mapped <- attach_exercise_mapping_fields(sets, mapping)
  unmapped <- unique(mapped[['exercise_raw']][is.na(mapped[['.mapped_exercise']])])
  unmapped <- unmapped[!is.na(unmapped) & trimws(unmapped) != '']

  if (length(unmapped) > 0) {
    abort_unmapped_exercises(unmapped)
  }

  mapped <- dplyr::mutate(
    mapped,
    exercise = .data[['.mapped_exercise']],
    exercise_variant = coalesce_optional_text(.data[['.mapped_exercise_variant']], .data[['exercise_variant']]),
    movement_group = .data[['.mapped_movement_group']],
    equipment_type = .data[['.mapped_equipment_type']]
  )

  dplyr::select(
    mapped,
    -dplyr::all_of(c('.mapped_exercise', '.mapped_exercise_variant', '.mapped_movement_group', '.mapped_equipment_type'))
  )
}

required_exercise_setup_columns <- function() {
  c('activity_id', 'date', 'exercise_raw', 'exercise_variant', 'review_status', 'notes')
}

empty_exercise_setups <- function() {
  tibble::tibble(
    activity_id = character(),
    date = as.Date(character()),
    exercise_raw = character(),
    exercise_variant = character(),
    review_status = character(),
    notes = character()
  )
}

default_exercise_setups_path <- function(path = NULL, lifting_sets_path = NULL) {
  if (!is.null(path)) {
    return(path)
  }
  if (!is.null(lifting_sets_path)) {
    return(file.path(dirname(lifting_sets_path), 'exercise_setups.csv'))
  }
  if (exists('find_project_root', mode = 'function')) {
    return(file.path(find_project_root(), 'data', 'processed', 'exercise_setups.csv'))
  }
  file.path('data', 'processed', 'exercise_setups.csv')
}

check_exercise_setups <- function(setups) {
  missing <- setdiff(required_exercise_setup_columns(), names(setups))
  if (length(missing) > 0) {
    rlang::abort(
      c(
        'Missing required column(s) in exercise setup assignments.',
        x = paste('Missing required column(s):', paste(missing, collapse = ', '))
      ),
      class = 'zlifts_missing_columns'
    )
  }

  blank_activity <- is.na(setups[['activity_id']]) | trimws(as.character(setups[['activity_id']])) == ''
  blank_raw <- is.na(setups[['exercise_raw']]) | trimws(as.character(setups[['exercise_raw']])) == ''
  blank_variant <- is.na(setups[['exercise_variant']]) | trimws(as.character(setups[['exercise_variant']])) == ''
  duplicate_key <- duplicated(setups[c('activity_id', 'exercise_raw')]) | duplicated(setups[c('activity_id', 'exercise_raw')], fromLast = TRUE)

  if (any(blank_activity | blank_raw | blank_variant)) {
    rlang::abort(
      'Exercise setup assignments must have activity_id, exercise_raw, and exercise_variant values.',
      class = 'zlifts_bad_exercise_setups'
    )
  }

  if (any(duplicate_key)) {
    rlang::abort(
      'Exercise setup assignments must be unique by activity_id and exercise_raw.',
      class = 'zlifts_bad_exercise_setups'
    )
  }

  invisible(setups)
}

read_exercise_setups <- function(path = NULL) {
  path <- default_exercise_setups_path(path)
  if (!file.exists(path)) {
    return(empty_exercise_setups())
  }

  setups <- readr::read_csv(
    path,
    col_types = readr::cols(
      activity_id = readr::col_character(),
      date = readr::col_date(),
      exercise_raw = readr::col_character(),
      exercise_variant = readr::col_character(),
      review_status = readr::col_character(),
      notes = readr::col_character()
    ),
    show_col_types = FALSE
  )

  check_exercise_setups(setups)
  setups
}

resolve_exercise_setups <- function(exercise_setups = NULL) {
  if (is.null(exercise_setups)) {
    return(empty_exercise_setups())
  }
  if (is.character(exercise_setups) && length(exercise_setups) == 1L) {
    return(read_exercise_setups(exercise_setups))
  }
  check_exercise_setups(exercise_setups)
  exercise_setups
}

attach_exercise_setup_fields <- function(sets, exercise_setups = NULL) {
  check_required_columns(sets, c('activity_id', 'exercise_raw'))
  setups <- resolve_exercise_setups(exercise_setups)

  if (nrow(setups) == 0L) {
    sets[['.setup_exercise_variant']] <- NA_character_
    return(sets)
  }

  setup_for_join <- dplyr::transmute(
    setups,
    activity_id = .data[['activity_id']],
    exercise_raw = .data[['exercise_raw']],
    .setup_exercise_variant = .data[['exercise_variant']]
  )

  dplyr::left_join(sets, setup_for_join, by = c('activity_id', 'exercise_raw'))
}

apply_exercise_setups <- function(sets, exercise_setups = NULL) {
  if (!'exercise_variant' %in% names(sets)) {
    sets[['exercise_variant']] <- NA_character_
  }

  assigned <- attach_exercise_setup_fields(sets, exercise_setups)
  assigned <- dplyr::mutate(
    assigned,
    exercise_variant = coalesce_optional_text(.data[['.setup_exercise_variant']], .data[['exercise_variant']])
  )

  dplyr::select(assigned, -dplyr::all_of('.setup_exercise_variant'))
}
