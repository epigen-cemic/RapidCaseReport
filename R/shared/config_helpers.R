# Shared country, geography, export, and table-display helpers.

#' Use a fallback for missing values
#'
#' Return the fallback when the primary value is NULL, empty, or a single NA.
#'
#' @param x Input value or object to process.
#' @param y Fallback value when x is missing.
#' @return The primary value or the fallback.
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

#' List countries with geographic mappings
#'
#' Return configured countries whose mapping section contains at least one level.
#'
#' @param geo_config Country and geographic-layer configuration.
#' @return A character vector of country names.
#' @keywords internal
valid_country_names <- function(geo_config) {
  if (is.null(geo_config) || length(geo_config) == 0) {
    return(character())
  }
  names(geo_config)[vapply(geo_config, function(cfg) {
    !is.null(cfg$mapping) && length(cfg$mapping) > 0
  }, logical(1))]
}

#' Get a country configuration
#'
#' Look up the named country mapping when the country selection is valid.
#'
#' @param geo_config Country and geographic-layer configuration.
#' @param country Configured country key.
#' @return The country configuration list or NULL.
#' @keywords internal
get_country_config <- function(geo_config, country) {
  if (is.null(country) || !nzchar(country) || is.null(geo_config[[country]])) {
    return(NULL)
  }
  geo_config[[country]]
}

#' Order configured geographic levels
#'
#' Return configured geographic level keys in the order specified by the country configuration.
#'
#' @param country_cfg Parsed settings for one country.
#' @return A character vector of geographic level keys.
#' @keywords internal
get_mapping_keys <- function(country_cfg) {
  configured <- country_cfg$levels %||% names(country_cfg$mapping)
  configured <- setdiff(configured, "country")
  configured[configured %in% names(country_cfg$mapping)]
}

#' Find a geographic level by its order
#'
#' Return the level key at the requested one-based position.
#'
#' @param country_cfg Parsed settings for one country.
#' @param position One-based position in the configured geographic hierarchy.
#' @return A geographic level key or NULL.
#' @keywords internal
get_level_key_by_position <- function(country_cfg, position) {
  keys <- get_mapping_keys(country_cfg)
  if (length(keys) < position) {
    return(NULL)
  }
  keys[[position]]
}

#' Get a geographic level mapping
#'
#' Retrieve the named mapping for the selected country and level.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A mapping list or NULL.
#' @keywords internal
get_mapping_config <- function(country_cfg, level_key) {
  if (is.null(country_cfg) || is.null(level_key)) {
    return(NULL)
  }
  country_cfg$mapping[[level_key]]
}

#' Find the finest configured geographic level
#'
#' Return the final mapped geographic level key.
#'
#' @param country_cfg Parsed settings for one country.
#' @return A character key or NULL.
#' @keywords internal
get_finest_level_key <- function(country_cfg) {
  keys <- get_mapping_keys(country_cfg)
  if (length(keys) == 0) {
    return(NULL)
  }
  keys[[length(keys)]]
}

#' Get finest-level geographic settings
#'
#' Return the mapping for the finest configured level.
#'
#' @param country_cfg Parsed settings for one country.
#' @return A geographic mapping list or NULL.
#' @keywords internal
get_finest_mapping_config <- function(country_cfg) {
  get_mapping_config(country_cfg, get_finest_level_key(country_cfg))
}

#' Resolve a geographic level from its data column
#'
#' Find the first level whose configured db_column matches the supplied name.
#'
#' @param country_cfg Parsed settings for one country.
#' @param db_column Configured source data column name.
#' @return A geographic level key or NULL.
#' @keywords internal
get_level_key_by_db_column <- function(country_cfg, db_column) {
  keys <- get_mapping_keys(country_cfg)
  matched <- keys[vapply(keys, function(key) {
    identical(country_cfg$mapping[[key]]$db_column, db_column)
  }, logical(1))]
  if (length(matched) == 0) {
    return(NULL)
  }
  matched[[1]]
}

#' Resolve a geographic UI label
#'
#' Return the configured label, display name, or generic level key.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A character display label.
#' @keywords internal
get_level_label <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$ui_label %||% level_cfg$display_name %||% level_key
}

#' Resolve a geographic display-name column
#'
#' Use the configured spatial name column or its label/identifier fallback.
#'
#' @param country_cfg Parsed settings for one country.
#' @param level_key Generic geographic level key such as level1, level2, or level3.
#' @return A character column name.
#' @keywords internal
get_level_name_col <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$name_col %||% level_cfg$label_col %||% level_cfg$spatial_id
}

#' Generate a timestamped report export name
#'
#' Combine a prefix and extension with the current timestamp.
#'
#' @param prefix Filename prefix.
#' @param ext Filename extension without the leading dot.
#' @return A character filename.
#' @keywords internal
timestamped_filename <- function(prefix, ext = "csv") {
  paste0(prefix, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".", ext)
}

#' Sanitize an export filename component
#'
#' Replace unsupported characters and use the configured fallback for an empty value.
#'
#' @param x Input value or object to process.
#' @param fallback Fallback filename component when input is blank.
#' @return A filename-safe character string.
#' @keywords internal
sanitize_filename_part <- function(x, fallback = "records") {
  x <- as.character(x %||% "")
  x <- gsub("[^A-Za-z0-9_-]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  if (!nzchar(x)) fallback else x
}

#' Write report data as UTF-8 CSV
#'
#' Export a data frame without row names using UTF-8 and blank missing fields.
#'
#' @param x Input value or object to process.
#' @param file File path for writing the export.
#' @return Invisible result of utils::write.csv().
#' @keywords internal
write_csv_utf8 <- function(x, file) {
  utils::write.csv(x, file, row.names = FALSE, fileEncoding = "UTF-8", na = "")
}

#' Create the reporting data table
#'
#' Build a compact, paginated DT widget for current-session records.
#'
#' @param data Data frame to show in a table.
#' @param page_length Number of rows to show on each DT page.
#' @return A DT HTML widget.
#' @keywords internal
app_datatable <- function(data, page_length = 10) {
  DT::datatable(
    data,
    rownames = FALSE,
    options = list(
      pageLength = page_length,
      autoWidth = TRUE,
      scrollX = TRUE
    ),
    class = "stripe hover compact"
  )
}
