#' Generate a report identifier
#'
#' Generate a UUID through the uuid package.
#'
#' @return A UUID character value.
#' @export
generate_id <- function() {
  uuid::UUIDgenerate()
}

#' Choose a Leaflet map zoom level
#'
#' Estimate a practical map zoom level from a geographic bounding box span.
#'
#' @param bbox Spatial bounding box with xmin, xmax, ymin and ymax.
#' @return A numeric zoom level.
#' @export
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

#' Update selected geographic values
#'
#' Set the supplied level and clear its descendants from the current geographic selection list.
#'
#' @param current_list List of currently selected geographic areas.
#' @param level Configured geographic level or database column.
#' @param value New selected geographic value.
#' @return The updated selection list.
#' @export
update_location_state <- function(current_list, level, value) {
  if (level == "level1") {
    current_list$level1 <- value
    current_list$level2 <- ""
    current_list$level3 <- ""
  } else if (level == "level2") {
    current_list$level2 <- value
    current_list$level3 <- ""
  } else if (level == "level3") {
    current_list$level3 <- value
  }
  return(current_list)
}
#' Prepare spatial geometries for Leaflet
#'
#' Attempt to repair invalid geometries and ensure an EPSG:4326 coordinate reference system for
#' display. When CRS is missing, the current code assumes WGS84.
#'
#' @details If no source CRS is declared, the implementation assigns EPSG:4326. That assumption
#'   must be validated against the geographic source.
#'
#' @param sf_object sf object to display on the map.
#' @return An sf object prepared for mapping.
#' @export
ensure_leaflet_crs <- function(sf_object) {
  if (is.null(sf_object) || nrow(sf_object) == 0) {
    return(sf_object)
  }

  sf_object <- sf::st_make_valid(sf_object)
  crs <- sf::st_crs(sf_object)

  if (is.na(crs)) {
    sf::st_crs(sf_object) <- 4326
    return(sf_object)
  }

  if (!identical(crs$epsg, 4326L)) {
    sf_object <- sf::st_transform(sf_object, 4326)
  }

  sf_object
}
