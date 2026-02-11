#' Generate a Unique Identifier
#'
#' Generates a random UUID string using the `uuid` package.
#'
#' @return A character string representing a unique UUID.
#' @importFrom uuid UUIDgenerate
#' @keywords internal
generate_id <- function() {
  uuid::UUIDgenerate()
}

#' Convert Data Frame Character Columns to UTF-8
#'
#' Iterates through all character columns in a data frame and converts their encoding
#' from `latin1` to `UTF-8`. This is critical for handling special characters in
#' administrative names (e.g., accents, tildes) coming from Shapefiles or GeoPackages.
#'
#' @param df A data frame or tibble.
#' @return A data frame with all character columns re-encoded to UTF-8.
#' @keywords internal
to_utf8 <- function(df) {
  df |>
    dplyr::mutate(dplyr::across(
      dplyr::where(base::is.character), 
      \(x) base::iconv(x, from = "latin1", to = "UTF-8", sub = "")
    ))
}

#' Pad ID based on Configuration
#'
#' Pads a numeric or character ID to a specific width with leading zeros,
#' based on the rules defined in the country configuration (e.g., Province IDs might need 2 digits).
#'
#' @param id The raw ID value (numeric or character).
#' @param level_name The name of the administrative level (e.g., "province", "department").
#' @param config The country configuration object containing the `padding` list.
#' @return A character string of the padded ID. Returns the original ID if no padding rule exists.
#' @keywords internal
pad_id <- function(id, level_name, config) {
  if (is.null(id) || is.na(id)) return("")
  pad_width <- config$padding[[level_name]]
  if (is.null(pad_width)) return(as.character(id))
  return(sprintf(paste0("%0", pad_width, "d"), as.numeric(id)))
}

#' Detect Geometry Column Name (RSQLite Safe Mode)
#'
#' Connects to a GeoPackage via RSQLite to inspect table fields and identify the
#' geometry column name (usually "geom" or "geometry"). This avoids loading the
#' entire file just to find the column name.
#'
#' @param dsn The path to the GeoPackage file.
#' @param table_name The specific table/layer name to inspect.
#' @return A character string ("geom" or "geometry") or NULL if not found.
#' @keywords internal
get_geom_name <- function(dsn, table_name) {
  con <- tryCatch({
    RSQLite::dbConnect(RSQLite::SQLite(), dsn)
  }, error = function(e) return(NULL))
  
  if (is.null(con)) return(NULL)
  fields <- tryCatch({
    RSQLite::dbListFields(con, table_name)
  }, error = function(e) return(NULL))
  RSQLite::dbDisconnect(con)
  
  if (is.null(fields)) return(NULL)
  if ("geom" %in% fields) return("geom")
  if ("geometry" %in% fields) return("geometry")
  return(NULL)
}

#' Universal Data Fetcher for Administrative Levels
#'
#' Fetches administrative boundary data from local GeoPackage (`.gpkg`) or Parquet (`.parquet`) files
#' based on the provided configuration. It handles filtering by parent ID and supports
#' fallback mechanisms (e.g., retrying a query with an unpadded ID if the padded version fails).
#'
#' @param level_name Character. The specific level to fetch (e.g., "department").
#' @param parent_val Character. The ID of the parent level to filter by (e.g., "06" for a province).
#' @param country_config List. The configuration object for the active country.
#' @return An `sf` object (for spatial data) or a `tibble` (for tabular data). Returns NULL on failure.
#' @export
fetch_level_data <- function(level_name, parent_val, country_config) {
  instr <- country_config$mapping[[level_name]]
  if (base::is.null(instr) || (!is.null(instr$type) && instr$type == "none")) return(NULL)
  
  country_name <- country_config$name 
  
  # --- Internal Helper: Perform Read Operation ---
  perform_read <- function(path, sql, target_geom) {
    if (!is.null(target_geom)) {
      tryCatch({
        return(sf::st_read(path, query = sql, geometry_column = target_geom, quiet = TRUE) |> to_utf8())
      }, error = function(e) { return(read_plain_table(path, sql)) })
    } else { return(read_plain_table(path, sql)) }
  }
  
  # --- Internal Helper: Fallback to SQL (Plain Table) ---
  read_plain_table <- function(path, sql) {
    con <- RSQLite::dbConnect(RSQLite::SQLite(), path)
    on.exit(RSQLite::dbDisconnect(con))
    df <- RSQLite::dbGetQuery(con, sql)
    return(df |> to_utf8())
  }
  # -----------------------------------------------
  
  base::tryCatch({
    if (instr$type == "gpkg") {
      path <- here::here("raw_data", country_name, base::paste0(instr$source, ".gpkg"))
      if (!base::file.exists(path)) {
        base::warning(base::sprintf("GPKG file missing at: %s", path))
        return(NULL)
      }
      
      # Inspect GPKG to find correct layer name (case-insensitive match)
      con <- RSQLite::dbConnect(RSQLite::SQLite(), path)
      all_tables <- RSQLite::dbListTables(con)
      RSQLite::dbDisconnect(con)
      
      data_tables <- all_tables[!grepl("^(gpkg_|sqlite_|rtree_)", all_tables)]
      internal_layer <- data_tables[tolower(data_tables) == tolower(instr$source)][1]
      if (is.na(internal_layer)) internal_layer <- data_tables[1]
      
      target_geom <- get_geom_name(path, internal_layer)
      
      # Construct SQL Query
      if (base::is.null(instr$parent_col) || base::is.null(parent_val) || parent_val == "") {
        sql <- base::sprintf("SELECT * FROM %s", internal_layer)
      } else {
        sql <- base::sprintf("SELECT * FROM %s WHERE %s = '%s'", 
                             internal_layer, instr$parent_col, parent_val)
      }
      
      result <- perform_read(path, sql, target_geom)
      
      # Fallback Mechanism: Try unpadded ID if 0 rows returned
      if (!is.null(parent_val) && nrow(result) == 0 && grepl("^0", parent_val)) {
        unpadded <- sub("^0+", "", parent_val)
        if (unpadded != parent_val) {
          sql_fallback <- base::sprintf("SELECT * FROM %s WHERE %s = '%s'", 
                                        internal_layer, instr$parent_col, unpadded)
          result_fallback <- perform_read(path, sql_fallback, target_geom)
          if(nrow(result_fallback) > 0) return(result_fallback)
        }
      }
      return(result)
      
    } else if (instr$type == "parquet") {
      parquet_path <- here::here("raw_data", country_name, base::paste0(instr$source, ".parquet"))
      if (!base::file.exists(parquet_path)) return(NULL)
      
      ds <- arrow::open_dataset(parquet_path)
      res <- ds |> dplyr::filter(!!rlang::sym(instr$parent_col) == parent_val) |> dplyr::collect()
      
      # Fallback Mechanism for Parquet
      if (nrow(res) == 0 && !is.null(parent_val) && grepl("^0", parent_val)) {
        unpadded <- sub("^0+", "", parent_val)
        res <- ds |> dplyr::filter(!!rlang::sym(instr$parent_col) == unpadded) |> dplyr::collect()
      }
      return(res)
    }
  }, error = function(e) { return(NULL) })
}

#' Plot and Center Spatial Object on Map
#'
#' Adds polygons to a Leaflet map proxy and automatically zooms the view to fit the data.
#' Supports custom fill colors and assigning data IDs to Leaflet layers for click interactivity.
#'
#' @param map_id Character. The ID of the leaflet map output (e.g., "map").
#' @param sf_object An `sf` object containing the polygons to draw.
#' @param session The Shiny session object.
#' @param id_col Character. The name of the column to use as the layer ID (for click events).
#' @param color Character. The color of the polygon borders.
#' @param weight Numeric. The thickness of the polygon borders.
#' @param fill_color Character. The color of the polygon fill (defaults to border color if NULL).
#' @param fill_opacity Numeric. The opacity of the fill (0 to 1).
#' @param draw Logical. If TRUE, clears previous shapes and draws new ones. If FALSE, only zooms.
#' @export
plot_on_map <- function(map_id, sf_object, session, id_col = NULL, color = "blue", weight = 2, 
                        fill_color = NULL, fill_opacity = 0.2, draw = FALSE) {
  
  if (is.null(sf_object) || nrow(sf_object) == 0) return()
  if (!inherits(sf_object, "sf")) return()
  
  if (is.null(fill_color)) fill_color <- color
  
  sf_object <- sf::st_make_valid(sf_object)
  bbox <- sf::st_bbox(sf_object)
  
  # Calculate Zoom Level based on Bounding Box size
  max_dim <- max(bbox$xmax - bbox$xmin, bbox$ymax - bbox$ymin)
  zoom_level <- dplyr::case_when(
    max_dim > 10 ~ 5, max_dim > 5 ~ 6, max_dim > 2 ~ 7,
    max_dim > 1 ~ 8, max_dim > 0.5 ~ 9, max_dim > 0.25 ~ 10,
    max_dim > 0.1 ~ 11, TRUE ~ 13
  )
  
  coords <- sf::st_centroid(sf_object) |> sf::st_coordinates()
  if(nrow(coords) > 1) coords <- coords[1, , drop = FALSE]
  
  proxy <- leaflet::leafletProxy(map_id, session = session)
  
  if (draw) {
    proxy <- proxy |> leaflet::clearShapes()
    
    if (!is.null(id_col) && id_col %in% names(sf_object)) {
      proxy <- proxy |> leaflet::addPolygons(
        data = sf_object, 
        layerId = as.character(sf_object[[id_col]]), 
        color = color,        
        weight = weight,      
        fillColor = fill_color, 
        fillOpacity = fill_opacity
      )
    } else {
      proxy <- proxy |> leaflet::addPolygons(
        data = sf_object, 
        color = color, 
        weight = weight, 
        fillColor = fill_color,
        fillOpacity = fill_opacity
      )
    }
  }
  
  proxy |> leaflet::setView(lng = coords[1], lat = coords[2], zoom = zoom_level)
}

#' Update Selected Location State (Dynamic Levels)
#'
#' Updates the reactive list of selected locations (or IDs). When a value is updated at a
#' specific level (e.g., "province"), this function automatically clears the values for
#' all subsequent levels (e.g., "department", "locality") to maintain hierarchy consistency.
#'
#' @param selected_location A `reactiveVal` containing the list of selected values.
#' @param level Character. The specific level being updated.
#' @param value Character. The new value to assign to that level.
#' @return Modifies the `selected_location` reactive object in place.
#' @export
update_location <- function(selected_location, level, value) {
  current <- selected_location()
  level_names <- names(current)
  match_idx <- match(level, level_names)
  
  if (is.na(match_idx)) return()
  
  current[[level]] <- value
  
  # Clear all levels below the current one
  if (match_idx < length(level_names)) {
    downstream_indices <- (match_idx + 1):length(level_names)
    for (i in downstream_indices) {
      current[[level_names[i]]] <- ""
    }
  }
  selected_location(current)
}