#' Update Geographic Hierarchy State
#'
#' @description Updates a generic geographic level (level1, level2, level3) within the location state list.
#' Automatically clears lower-level geographies when a higher-level one changes.
#'
#' @param current_location A list representing the current state of selected generic locations.
#' @param target_level Character. The geographic hierarchy level to update ("level1", "level2", "level3").
#' @param value Character or Numeric. The new value to assign to the specified level.
#'
#' @return A modified list containing the updated location state.
#' @export
update_location <- function(current_location, target_level, value) {

  if (target_level == "level1") {
    current_location$level1 <- value
    current_location$level2 <- ""
    current_location$level3 <- ""

  } else if (target_level == "level2") {
    current_location$level2 <- value
    current_location$level3 <- ""

  } else if (target_level == "level3") {
    current_location$level3 <- as.character(value)
  }

  return(current_location)
}

#' Plot Spatial Object on Map
#'
#' @description Updates a Leaflet map to focus on a spatial object and optionally draw it.
#'
#' @param map_id Character. The ID of the Leaflet map.
#' @param sf_object sf object. The spatial features to plot.
#' @param session The Shiny session object.
#' @param color Character. Border color.
#' @param weight Numeric. Stroke weight.
#' @param draw Logical. If TRUE, clears previous shapes and draws the new ones.
#'
#' @export
plot_on_map <- function(map_id, sf_object, session, color = "blue", weight = 2, draw = FALSE) {
  if (is.null(sf_object) || nrow(sf_object) == 0) {
    return(invisible(NULL))
  }

  sf_object <- ensure_leaflet_crs(sf_object)
  bbox <- sf::st_bbox(sf_object)
  zoom_level <- get_zoom(bbox)

  centroid <- sf::st_centroid(sf::st_union(sf_object))
  coords <- sf::st_coordinates(centroid)

  proxy <- leaflet::leafletProxy(map_id, session = session)

  if (draw) {
    proxy <- proxy %>%
      leaflet::clearShapes() %>%
      leaflet::addPolygons(data = sf_object, color = color, weight = weight)
  }

  proxy %>%
    leaflet::setView(lng = coords[1], lat = coords[2], zoom = zoom_level) %>%
    leaflet::fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax)
}

#' Plot Generic Finest-Level Areas on Map
#'
#' @description Renders the finest configured geographic level on a Leaflet map.
#' Highlights a specifically selected area and updates the corresponding UI text input.
#'
#' @param map_id Character. The ID of the Leaflet map output.
#' @param sf_level3 An sf object containing all shapes for the current finest-level context.
#' @param country Character. The selected country name.
#' @param geo_config List. The global geographic configuration.
#' @param selected_id Character or NULL. The specific ID of the area to highlight.
#' @param session The Shiny session object.
#'
#' @export
plot_finest_areas <- function(map_id, sf_level3, country, geo_config, selected_id, session) {
  if (is.null(sf_level3) || nrow(sf_level3) == 0) {
    return(invisible(NULL))
  }

  country_cfg <- geo_config[[country]]
  finest_key <- get_finest_level_key(country_cfg)
  l3_cfg <- get_finest_mapping_config(country_cfg)
  id_col <- l3_cfg$spatial_id
  level_label <- get_level_label(country_cfg, finest_key)

  sf_level3 <- ensure_leaflet_crs(sf_level3)

  leaflet::leafletProxy(map_id, session = session) %>%
    leaflet::clearShapes() %>%
    leaflet::addPolygons(
      data = sf_level3,
      color = "red",
      weight = 2,
      layerId = as.character(sf_level3[[id_col]])
    )

  if (!is.null(selected_id) && selected_id != "") {
    selected_row <- sf_level3[as.character(sf_level3[[id_col]]) == as.character(selected_id), ]
    if (nrow(selected_row) == 0) {
      return(invisible(NULL))
    }
    selected_row <- ensure_leaflet_crs(selected_row)

    shiny::updateTextInput(session, "level3", value = paste("Selected", level_label, "ID:", selected_id))

    leaflet::leafletProxy(map_id, session = session) %>%
      leaflet::addPolygons(
        data = selected_row,
        color = "green",
        weight = 3,
        layerId = selected_id
      )

    plot_on_map(map_id, selected_row, session)

  } else {
    shiny::updateTextInput(session, "level3", value = "Select on the map")
  }
}

# Backwards-compatible alias for older code paths.
plot_fractions <- plot_finest_areas
