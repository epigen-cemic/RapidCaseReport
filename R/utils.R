# Generate unique ID
generate_id <- function() {
  UUIDgenerate()
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

# Udate Selection
update_location <- function(selected_location, level, value) {
  current <- selected_location()
  
  if (level == "province") {
    current$province <- value
    current$department <- ""
    current$locality <- ""
    current$census_fraction <- ""
    
  } else if (level == "department") {
    current$department <- value
    current$locality <- ""
    current$census_fraction <- ""
    
  } else if (level == "locality") {
    current$locality <- value
    
  } else if (level == "census_fraction") {
    # pad left with zeros if numeric code
    current$census_fraction <- as.character(sprintf("%07s", value))
  }
  
  selected_location(current)
}

# Area ploting
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

plot_on_map <- function(map_id, sf_object, session, color = "blue", weight = 2, draw = FALSE) {
  sf_object <- st_make_valid(sf_object)
  bbox <- st_bbox(sf_object)
  zoom_level <- get_zoom(bbox)
  centroid <- st_centroid(sf_object)
  coords <- st_coordinates(centroid)
  
  proxy <- leafletProxy(map_id, session = session)
  
  if (draw) {
    proxy <- proxy %>%
      clearShapes() %>%
      addPolygons(data = sf_object, color = color, weight = weight)
  }
  
  proxy %>%
    setView(lng = coords[1], lat = coords[2], zoom = zoom_level) %>%
    fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax)
}

plot_fractions <- function(map_id, fracc, selected_cde, cod_indec_selected, session) {
  # filter all fractions in department
  fraccs_filtered <- fracc[fracc$cde == selected_cde, ]
  
  # draw all in red (no zooming here)
  leafletProxy(map_id) %>%
    clearShapes() %>%
    addPolygons(data = fraccs_filtered, color = "red", weight = 2,
                popup = ~cfn, layerId = ~cod_indec)
  
  # if a specific fraction is selected
  if (!is.null(cod_indec_selected) && cod_indec_selected != "") {
    fracc_selected <- fracc[as.character(fracc$cod_indec) == as.character(cod_indec_selected), ]
    fracc_selected <- st_make_valid(fracc_selected)
    
    updateTextInput(session, "Fraction",
                    value = paste("Selected area:", fracc_selected$cfn))
    
    # highlight in green and zoom using plot_on_map
    leafletProxy(map_id) %>%
      addPolygons(data = fracc_selected, color = "green", weight = 2,
                  popup = ~cfn, layerId = ~cod_indec)
    
    plot_on_map(map_id, fracc_selected, session)  # reuse zoom+view logic
  } else {
    updateTextInput(session, "Fraction", value = "Select on the map")
  }
}
