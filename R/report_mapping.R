#' Update a geographic selection list
#'
#' Set one geographic level and clear lower-level values when a parent changes.
#'
#' @param current_location List of currently selected geographic areas.
#' @param target_level Geographic level to update.
#' @param value New selected geographic value.
#' @return The updated geographic selection list.
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

#' Draw a spatial layer in Leaflet
#'
#' Center or draw an sf object on the existing map with the supplied border settings.
#'
#' @param map_id Namespace-qualified Leaflet map output identifier.
#' @param sf_object sf object to display on the map.
#' @param session Active Shiny session.
#' @param color Leaflet shape border color.
#' @param weight Leaflet shape border width.
#' @param draw Whether to redraw the shapes on the map.
#' @return A Leaflet proxy result.
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

#' Display selectable finest-level areas
#'
#' Draw the configured finest geographic units, highlight the selected area, and update its
#' identifier field.
#'
#' @param map_id Namespace-qualified Leaflet map output identifier.
#' @param sf_level3 sf object containing available finest-level geographic areas.
#' @param country Configured country key.
#' @param geo_config Country and geographic-layer configuration.
#' @param selected_id Identifier of the area to highlight.
#' @param session Active Shiny session.
#' @return A Leaflet proxy/update result.
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
