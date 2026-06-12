# Shared helper functions for RapidCaseReport v2.0

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

valid_country_names <- function(geo_config) {
  if (is.null(geo_config) || length(geo_config) == 0) {
    return(character())
  }
  names(geo_config)[vapply(geo_config, function(cfg) {
    !is.null(cfg$mapping) && length(cfg$mapping) > 0
  }, logical(1))]
}

get_country_config <- function(geo_config, country) {
  if (is.null(country) || !nzchar(country) || is.null(geo_config[[country]])) {
    return(NULL)
  }
  geo_config[[country]]
}

get_mapping_keys <- function(country_cfg) {
  configured <- country_cfg$levels %||% names(country_cfg$mapping)
  configured <- setdiff(configured, "country")
  configured[configured %in% names(country_cfg$mapping)]
}

get_level_key_by_position <- function(country_cfg, position) {
  keys <- get_mapping_keys(country_cfg)
  if (length(keys) < position) {
    return(NULL)
  }
  keys[[position]]
}

get_mapping_config <- function(country_cfg, level_key) {
  if (is.null(country_cfg) || is.null(level_key)) {
    return(NULL)
  }
  country_cfg$mapping[[level_key]]
}

get_finest_level_key <- function(country_cfg) {
  keys <- get_mapping_keys(country_cfg)
  if (length(keys) == 0) {
    return(NULL)
  }
  keys[[length(keys)]]
}

get_finest_mapping_config <- function(country_cfg) {
  get_mapping_config(country_cfg, get_finest_level_key(country_cfg))
}

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

get_level_label <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$ui_label %||% level_cfg$display_name %||% level_key
}

get_level_name_col <- function(country_cfg, level_key) {
  level_cfg <- get_mapping_config(country_cfg, level_key)
  level_cfg$name_col %||% level_cfg$label_col %||% level_cfg$spatial_id
}

timestamped_filename <- function(prefix, ext = "csv") {
  paste0(prefix, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".", ext)
}

sanitize_filename_part <- function(x, fallback = "records") {
  x <- as.character(x %||% "")
  x <- gsub("[^A-Za-z0-9_-]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  if (!nzchar(x)) fallback else x
}

write_csv_utf8 <- function(x, file) {
  utils::write.csv(x, file, row.names = FALSE, fileEncoding = "UTF-8", na = "")
}

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
