#' Generate a Unique Identifier
#'
#' @description Generates a universally unique identifier (UUID).
#'
#' @return A character string containing the UUID.
#' @export
generate_id <- function() {
  uuid::UUIDgenerate()
}

#' Calculate Map Zoom Level
#'
#' @description Determines the appropriate map zoom level based on the dimensions of a spatial bounding box.
#'
#' @param bbox A spatial bounding box object (e.g., from sf::st_bbox) containing xmin, xmax, ymin, and ymax.
#'
#' @return A numeric value representing the recommended zoom level.
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

#' Update Generic Location State
#' @description Updates abstract levels without hardcoded country terms.
#' @param current_list List. The current location state.
#' @param level Character. The level to update ("level1", "level2", "level3").
#' @param value Character. The new selection value.
#' @return A modified list.
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
#' Ensure spatial data are valid WGS84 geometries for Leaflet
#'
#' @description Leaflet expects longitude/latitude coordinates in EPSG:4326.
#' This helper validates geometries and transforms them when a different CRS is
#' declared.
#'
#' @param sf_object An sf object.
#' @return An sf object with valid EPSG:4326 geometries where possible.
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
