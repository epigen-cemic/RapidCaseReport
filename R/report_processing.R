#' Validate required case form fields
#'
#' Check selected demographic, geographic, symptom, diagnosis, and professional fields and reject
#' birth dates after consultation dates.
#'
#' @param consultation_date Date of consultation selected in the form.
#' @param birth_date Date of birth selected in the form.
#' @param sex Selected sex category.
#' @param loc List of selected country and geographic area values.
#' @param symptom_description Free-text symptom description.
#' @param suspected_diagnosis Free-text suspected diagnosis.
#' @param email Reporting professional email address.
#' @param institution Name of reporting institution.
#' @return A character vector of validation messages; empty when no listed error is found.
#' @export
validate_form_inputs <- function(consultation_date, birth_date, sex, loc, symptom_description, suspected_diagnosis, email, institution) {
  errors <- character()

  # Validate mandatory report and professional information.
  if (sex == "") errors <- c(errors, "Please select a Sex.")
  if (email == "") errors <- c(errors, "Email is required.")
  if (institution == "") errors <- c(errors, "Institution is required.")
  if (symptom_description == "") errors <- c(errors, "Symptom description is required.")
  if (suspected_diagnosis == "") errors <- c(errors, "Suspected diagnosis is required.")
  if (email != "" && !grepl("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email)) {
    errors <- c(errors, "Please enter a valid email address.")
  }

  # Require a country and a finest-level area selected on the map.
  if (is.null(loc$country) || loc$country == "") errors <- c(errors, "Please select a Country.")
  if (is.null(loc$level3) || loc$level3 == "" || loc$level3 == "Select on the map") {
    errors <- c(errors, "Please select a specific area on the map (Level 3).")
  }

  # Disallow a birth date later than the consultation date.
  if (birth_date > consultation_date) {
    errors <- c(errors, "Birth date cannot be after the consultation date.")
  }

  return(errors)
}


#' Convert report text from Latin-1 to UTF-8
#'
#' Convert character columns of a data frame using the explicitly specified Latin-1 source
#' encoding.
#'
#' @param df Data frame containing input or output records.
#' @return A data frame with converted character fields.
#' @export
to_utf8 <- function(df) {
  char_cols <- names(df)[sapply(df, is.character)]

  for (colname in char_cols) {
    df[[colname]] <- iconv(df[[colname]], from = "latin1", to = "UTF-8", sub = "")
  }

  return(df)
}


#' Read a configured geographic layer
#'
#' Resolve a country and level into a GeoPackage query, optionally filter by one field, prepare
#' geometries for Leaflet, and normalize text encoding.
#'
#' @details The current WHERE query uses string interpolation rather than parameter binding. Treat
#'   input values as trusted configuration until query construction is hardened.
#'
#' @param information SQL column expression to select from the spatial layer.
#' @param country Configured country key.
#' @param level Configured geographic level or database column.
#' @param geo_config Country and geographic-layer configuration.
#' @param data_dir Directory containing configured GeoPackage files.
#' @param type Optional spatial-layer column to compare in a WHERE clause.
#' @param name Value to compare against the selected geographic field.
#' @return An sf object from the requested layer.
#' @export
get_info_about <- function(information, country, level, geo_config, data_dir, type = NULL, name = NULL) {
  country_cfg <- geo_config[[country]]

  level_key <- get_level_key_by_db_column(country_cfg, level) %||% level
  layer_info <- get_mapping_config(country_cfg, level_key)
  if (is.null(layer_info)) {
    stop("No geographic mapping found for level: ", level, call. = FALSE)
  }

  file_path <- file.path(data_dir, country_cfg$file_name)
  if (!file.exists(file_path)) {
    stop("Geographic data file not found: ", file_path, call. = FALSE)
  }

  sql <- if (!is.null(type)) {
    sprintf("SELECT %s FROM %s WHERE %s = '%s'", information, layer_info$layer_name, type, name)
  } else {
    sprintf("SELECT %s FROM %s", information, layer_info$layer_name)
  }

  result <- sf::st_read(file_path, query = sql, quiet = TRUE)
  result <- ensure_leaflet_crs(result)
  return(to_utf8(result)) # Prepare text for UI display.
}

#' Build a report row from the form
#'
#' Flatten form and geographic state into a single record with a generated UUID and submission
#' timestamp.
#'
#' @param input Shiny input object for the current module.
#' @param loc List of selected country and geographic area values.
#' @return A one-row data frame matching the local reports schema.
#' @export
format_new_entry <- function(input, loc) {
  # Keep the report-to-storage field mapping in one place so all submissions
  # use the same field names and timestamp format.

  submitted_time <- as.character(Sys.time())

  data.frame(
    id_code = generate_id(), # Calls generic utility from utils.R
    consultation_date = as.character(input$consultation_date),
    sex = input$sex,
    birth_date = as.character(input$birth_date),
    country = loc$country,
    level1 = loc$level1,
    level2 = loc$level2,
    level3 = loc$level3,
    symptom_onset_date = as.character(input$symptom_onset_date),
    symptom_description = input$symptom_description,
    suspected_diagnosis = input$suspected_diagnosis,
    confirmation_time = submitted_time,
    submitted_at = submitted_time,
    email = input$email,
    institution = input$institution,
    stringsAsFactors = FALSE
  )
}
