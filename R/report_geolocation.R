#' Build the geographic selection interface
#'
#' Create cascading geographic selectors, a read-only finest-area identifier field, and a Leaflet
#' map output.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @return A list containing sidebar and main UI elements.
#' @export
geoLocationUI <- function(id) {
  ns <- NS(id)
  sidebar <- tagList(
    selectInput(ns("country"), "Select Country:", choices = c("Select a Country" = "")),
    selectInput(ns("level1"), "Select Level 1:", choices = c("No information available" = "")),
    selectInput(ns("level2"), "Select Level 2:", choices = c("No information available" = "")),
    # Read-only text box for the final ID
    shinyjs::disabled(
      textInput(ns("level3"), "Selected Area (ID):", value = "Select on the map", width = "100%")
    ),
    actionButton(ns("reset_geo"), "Reset locations",
                 icon = icon("sync"),
                 class = "btn-link-custom")
  )
  main <- div(class = "map-panel", leafletOutput(ns("map"), height = "600px", width = "100%"))
  list(sidebar = sidebar, main = main)
}

#' Manage geographic selection and map interactions
#'
#' Load configured spatial levels, update dependent selectors and map layers, and store the
#' selected country and area values.
#'
#' @param id Character Shiny module identifier used for namespacing.
#' @param geo_config Country and geographic-layer configuration.
#' @param data_dir Directory containing configured GeoPackage files.
#' @return A reactive expression for the current geographic selection.
#' @export
geoLocationServer <- function(id, geo_config, data_dir) {
  moduleServer(id, function(input, output, session) {

    # --- Internal Reactive State ---
    level1_data <- reactiveVal(NULL)
    level2_data <- reactiveVal(NULL)
    level3_data <- reactiveVal(NULL)

    selected_location <- reactiveVal(list(
      country = NULL, level1 = NULL, level2 = NULL, level3 = NULL
    ))

    valid_countries <- valid_country_names(geo_config)
    updateSelectInput(session, "country", choices = c("Select a Country" = "", valid_countries))

    # Initialize the map
    output$map <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        setView(lng = -63.6, lat = -38.4, zoom = 5)
    })

    #' Reset dependent geographic selections
    #'
    #' Clear geographic selections beneath the country level and reset the map state when a
    #' higher-level selection changes.
    #'
    #' @return The side-effect result of updating geographic input controls.
    #' @keywords internal
    # Clearing a parent selection must also invalidate all lower-level areas.
    reset_to_level_1 <- function() {
      updateTextInput(session, "level3", value = "Select on the map")
      updateSelectInput(session, "level2", choices = c("No information available" = ""))
      new_loc <- selected_location()
      new_loc$level2 <- NULL
      new_loc$level3 <- NULL
      selected_location(new_loc)
    }

    observeEvent(input$reset_geo, {
      level1_data(NULL)
      level2_data(NULL)
      level3_data(NULL)
      selected_location(list(country = NULL, level1 = NULL, level2 = NULL, level3 = NULL))

      updateSelectInput(session, "country", selected = "")
      updateSelectInput(session, "level1", choices = c("No information available" = ""), selected = "")
      updateSelectInput(session, "level2", choices = c("No information available" = ""), selected = "")
      updateTextInput(session, "level3", value = "Select on the map")

      leafletProxy("map", session = session) %>%
        clearShapes() %>%
        setView(lng = -63.6, lat = -38.4, zoom = 5)

      showNotification("Geographic selections cleared.", type = "message")
    })

    # --- Observer: Country Selection ---
    observeEvent(input$country, {
      req(input$country != "")
      reset_to_level_1()

      country_cfg <- geo_config[[input$country]]
      level1_key <- get_level_key_by_position(country_cfg, 1)
      level2_key <- get_level_key_by_position(country_cfg, 2)
      level3_key <- get_level_key_by_position(country_cfg, 3)
      req(!is.null(level1_key))

      level1_cfg <- get_mapping_config(country_cfg, level1_key)
      df <- get_info_about("*", input$country, level1_cfg$db_column, geo_config, data_dir)
      level1_data(df)

      level1_name_col <- get_level_name_col(country_cfg, level1_key)
      updateSelectInput(
        session,
        "level1",
        label = paste0("Select ", get_level_label(country_cfg, level1_key), ":"),
        choices = c("Select:" = "", sort(unique(as.character(df[[level1_name_col]]))))
      )
      updateSelectInput(
        session,
        "level2",
        label = if (!is.null(level2_key)) paste0("Select ", get_level_label(country_cfg, level2_key), ":") else "Select Level 2:",
        choices = c("No information available" = "")
      )
      updateTextInput(
        session,
        "level3",
        label = if (!is.null(level3_key)) paste0("Selected ", get_level_label(country_cfg, level3_key), " (ID):") else "Selected Area (ID):",
        value = "Select on the map"
      )

      new_loc <- selected_location()
      new_loc$country <- input$country
      selected_location(new_loc)
    })

    # --- Observer: Level 1 Selection ---
    observeEvent(input$level1, {
      req(input$level1 != "")
      updateTextInput(session, "level3", value = "Select on the map")

      country_cfg <- geo_config[[input$country]]
      level1_key <- get_level_key_by_position(country_cfg, 1)
      level2_key <- get_level_key_by_position(country_cfg, 2)
      req(!is.null(level1_key), !is.null(level2_key))

      level1_name_col <- get_level_name_col(country_cfg, level1_key)
      l1_selected <- level1_data()[as.character(level1_data()[[level1_name_col]]) == input$level1, ]
      l1_cfg <- get_mapping_config(country_cfg, level1_key)
      parent_id <- as.character(unique(l1_selected[[l1_cfg$spatial_id]]))

      level2_cfg <- get_mapping_config(country_cfg, level2_key)
      df <- get_info_about("*", input$country, level2_cfg$db_column, geo_config, data_dir,
                           type = level2_cfg$parent_col, name = parent_id)
      level2_data(df)

      level2_name_col <- get_level_name_col(country_cfg, level2_key)
      updateSelectInput(
        session,
        "level2",
        label = paste0("Select ", get_level_label(country_cfg, level2_key), ":"),
        choices = c("Select:" = "", sort(unique(as.character(df[[level2_name_col]]))))
      )
      plot_on_map("map", l1_selected, session, draw = TRUE)

      selected_location(update_location_state(selected_location(), "level1", input$level1))
    })

    # --- Observer: Level 2 Selection ---
    observeEvent(input$level2, {
      req(input$level2 != "")

      country_cfg <- geo_config[[input$country]]
      level2_key <- get_level_key_by_position(country_cfg, 2)
      level3_key <- get_level_key_by_position(country_cfg, 3)
      req(!is.null(level2_key), !is.null(level3_key))

      level2_name_col <- get_level_name_col(country_cfg, level2_key)
      l2_selected <- level2_data()[as.character(level2_data()[[level2_name_col]]) == input$level2, ]
      l2_cfg <- get_mapping_config(country_cfg, level2_key)
      parent_id <- as.character(unique(l2_selected[[l2_cfg$spatial_id]]))

      level3_cfg <- get_mapping_config(country_cfg, level3_key)
      df <- get_info_about("*", input$country, level3_cfg$db_column, geo_config, data_dir,
                           type = level3_cfg$parent_col, name = parent_id)
      level3_data(df)

      plot_on_map("map", l2_selected, session)
      plot_finest_areas("map", df, input$country, geo_config, NULL, session)
      selected_location(update_location_state(selected_location(), "level2", input$level2))
    })

    # --- Observer: Map Click (Level 3) ---
    observeEvent(input$map_shape_click, {
      clicked_id <- input$map_shape_click$id
      req(clicked_id)
      plot_finest_areas("map", level3_data(), input$country, geo_config, clicked_id, session)
      selected_location(update_location_state(selected_location(), "level3", clicked_id))
    })

    return(selected_location)
  })
}
