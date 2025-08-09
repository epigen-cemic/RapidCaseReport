# Generate unique ID
generate_id <- function() {
  UUIDgenerate()
}

# Center on ploted area

get_zoom <- function(bbox) {
  max_dim <- max(bbox$xmax - bbox$xmin, bbox$ymax - bbox$ymin)
  dplyr::case_when(
    max_dim > 10 ~ 5,
    max_dim > 5 ~ 6,
    max_dim > 2 ~ 7,
    max_dim > 1 ~ 8,
    max_dim > 0.5 ~ 9,
    max_dim > 0.25 ~ 10,
    max_dim > 0.1 ~ 11,
    TRUE ~ 13
  )
}

# Text Manipulation

to_utf8 <- function(df) {
  char_cols <- names(df)[sapply(df, is.character)]
  for (colname in char_cols) {
    df[[colname]] <- iconv(df[[colname]], from = "latin1", to = "UTF-8", sub = "")
  }
  return(df)
}

# query data from files

get_info_about <- function(information, layer, type = NULL, name = NULL) {
  if (!is.null(type) && !is.null(name)) {
    # Conditional query to search for specific data
    sql <- sprintf("SELECT %s FROM %s_indec WHERE %s = '%s'", information, layer, type, name)
  } else {
    # Query every entry from a specific column
    sql <- sprintf("SELECT %s FROM %s_indec", information, layer)
  }
  file_name <- sprintf("%s_indec.gpkg", layer)
  result <- sf::st_read(here("raw_data", file_name), query = sql, quiet = TRUE)
  result <- to_utf8(result)
  return(result)
}
