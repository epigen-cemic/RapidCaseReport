#' Dynamic Geo-Location Server Module
#'
#' Handles the server-side logic for the dynamic geo-location selector.
#' This module performs several key functions:
#' \itemize{
#'   \item **Dynamic UI Generation:** Uses `renderUI` to create dropdowns for administrative levels
#'         defined in the selected country's configuration.
#'   \item **Cascading Logic:** Automatically updates child levels when a parent level changes
#'         (e.g., selecting a Province filters the Department list).
#'   \item **Map Interaction:** Updates the Leaflet map to zoom into the selected region and
#'         handles click events for selecting regions via the map.
#'   \item **Manual Selection Mode:** For levels without names (e.g., Census Fractions), it
#'         enables a "Manual Mode" where users must select from the map, visually highlighting
#'         the selection.
#' }
#'
#' @param id Character. The module ID used to namespace inputs and outputs.
#'
#' @return A `reactiveVal` list containing the names of the selected locations for all levels
#'         (e.g., list(country="Argentina", province="Buenos Aires", ...)).
#' 
#' @importFrom shiny moduleServer reactive reactiveVal req observeEvent observe renderUI selectInput textInput updateTextInput updateSelectInput
#' @importFrom shinyjs show hide enable disable runjs
#' @importFrom leaflet leafletProxy setView clearShapes addPolygons removeShape leaflet renderLeaflet addTiles
#' @export
geoLocationServer <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # --- 1. Reactive State
    active_config <- shiny::reactive({
      shiny::req(input$country)
      ALL_CONFIGS[[input$country]]
    })
    
    # Cache first level
    first_level_data <- shiny::reactive({
      config <- active_config()
      if (config$mapping[[config$levels[2]]]$type == "none") return(NULL)
      first_sub_level <- config$levels[2]
      fetch_level_data(first_sub_level, parent_val = NULL, country_config = config)
    })
    
    selected_location <- shiny::reactiveVal(base::list())
    selected_ids <- shiny::reactiveVal(base::list())
    current_highlight_id <- shiny::reactiveVal(NULL)
    
    # FIX: Explicitly track which level is in "Map Selection Mode"
    active_manual_level <- shiny::reactiveVal(NULL)
    
    
    # --- 2. DYNAMIC UI GENERATION ---
    output$dynamic_levels_ui <- shiny::renderUI({
      shiny::req(input$country)
      config <- active_config()
      hierarchy_levels <- config$levels[-1] 
      first_data <- first_level_data()
      
      ui_elements <- base::lapply(seq_along(hierarchy_levels), function(i) {
        lvl <- hierarchy_levels[i]
        is_first <- (i == 1)
        initial_choices <- c("Select an option" = "")
        
        if (is_first && !is.null(first_data)) {
          cols <- names(first_data)
          name_col <- cols[grep("^(nam|name)$", cols, ignore.case = TRUE)][1]
          if (!is.na(name_col)) {
            vals <- base::sort(base::unique(first_data[[name_col]]))
            initial_choices <- c("Select an option" = "", stats::setNames(vals, vals))
          }
        }
        
        wrapper <- if (is_first) shiny::tagList else shinyjs::disabled
        wrapper(
          shiny::div(
            id = ns(base::paste0("container_", lvl)),
            shiny::selectInput(
              ns(lvl), 
              label = base::paste0("Select ", tools::toTitleCase(lvl), ":"), 
              choices = initial_choices, multiple = FALSE, selected = ""
            ),
            shiny::div(
              id = ns(base::paste0("manual_wrapper_", lvl)),
              style = "display: none;", 
              shiny::textInput(
                ns(base::paste0("manual_", lvl)), 
                label = base::paste0(tools::toTitleCase(lvl), " Selection:"), 
                value = "Select on the map", width = "100%",
                placeholder = "Click a region on the map"
              )
            )
          )
        )
      })
      shiny::tagList(ui_elements)
    })
    
    
    # --- 3. Observer: Master Country Trigger ---
    shiny::observeEvent(input$country, {
      shiny::req(input$country != "")
      config <- active_config()
      
      init_list <- stats::setNames(as.list(base::rep("", base::length(config$levels))), config$levels)
      init_list$country <- input$country
      selected_location(init_list)
      selected_ids(init_list) 
      current_highlight_id(NULL)
      active_manual_level(NULL) # Reset Manual Mode
      
      first_data <- first_level_data()
      if (!is.null(first_data) && nrow(first_data) > 0) {
        plot_on_map("map", first_data, session, draw = TRUE)
        leaflet::leafletProxy("map") |>
          leaflet::setView(lng = config$initial_view$lng, 
                           lat = config$initial_view$lat, 
                           zoom = config$initial_view$zoom)
      } else {
        leaflet::leafletProxy("map") |> leaflet::clearShapes()
      }
    })
    
    
    # --- 4. Observer: Cascading Dropdown Logic ---
    shiny::observe({
      shiny::req(input$country)
      config <- active_config()
      sub_levels <- config$levels[-1]
      
      base::lapply(seq_along(sub_levels), function(i) {
        level_name <- sub_levels[i]
        next_level <- if (i < length(sub_levels)) sub_levels[i + 1] else NULL
        
        shiny::observeEvent(input[[level_name]], {
          val <- input[[level_name]]
          
          # Handle Clear
          if (is.null(val) || val == "") {
            # Check if we are clearing the parent of the manual level
            if (!is.null(next_level)) {
              active_manual_level(NULL) # Exit Manual Mode if moving up
              remaining <- sub_levels[(i + 1):length(sub_levels)]
              base::lapply(remaining, function(rlvl) {
                shinyjs::disable(base::paste0("container_", rlvl))
                shiny::updateSelectInput(session, rlvl, choices = c("Select an option" = ""), selected = "")
                shinyjs::hide(base::paste0("manual_wrapper_", rlvl))
                shinyjs::show(rlvl)
              })
            }
            return()
          }
          
          # --- ID TRANSLATION ---
          parent_id_val <- if (i == 1) NULL else selected_ids()[[sub_levels[i-1]]]
          parent_data <- fetch_level_data(level_name, parent_val = parent_id_val, country_config = config)
          
          selected_id <- val 
          target_row <- NULL
          
          if (!is.null(parent_data)) {
            cols <- names(parent_data)
            name_col <- cols[grep("^(nam|name)$", cols, ignore.case = TRUE)][1]
            if (!is.na(name_col)) {
              target_row <- parent_data[parent_data[[name_col]] == val, ]
              if (nrow(target_row) > 0) {
                raw_id <- NULL
                if (!is.null(next_level)) {
                  next_mapping <- config$mapping[[next_level]]
                  required_col <- next_mapping$parent_col 
                  if (!is.null(required_col)) {
                    match_col <- cols[grep(paste0("^", required_col, "$"), cols, ignore.case = TRUE)][1]
                    if (!is.na(match_col)) raw_id <- target_row[[match_col]][1]
                  }
                }
                if (is.null(raw_id) && "link" %in% cols) raw_id <- target_row[["link"]][1]
                selected_id <- pad_id(raw_id, level_name, config)
              }
            }
          }
          
          update_location(selected_location, level_name, val)
          update_location(selected_ids, level_name, selected_id) 
          
          map_updated <- FALSE 
          
          # --- TRIGGER NEXT LEVEL ---
          if (!is.null(next_level)) {
            next_data <- fetch_level_data(next_level, parent_val = selected_id, country_config = config)
            
            shinyjs::show(base::paste0("container_", next_level))
            shinyjs::enable(base::paste0("container_", next_level))
            
            if (!is.null(next_data) && nrow(next_data) > 0) {
              ncols <- names(next_data)
              next_name_col <- ncols[grep("^(nam|name|localidad)$", ncols, ignore.case = TRUE)][1]
              
              if (!is.na(next_name_col)) {
                # CASE 1: Dropdown Mode
                active_manual_level(NULL) # Not in manual mode
                shinyjs::show(next_level)
                shinyjs::hide(base::paste0("manual_wrapper_", next_level))
                choices_vec <- base::sort(base::unique(next_data[[next_name_col]]))
                shiny::updateSelectInput(session, next_level, 
                                         choices = base::as.list(stats::setNames(choices_vec, choices_vec)),
                                         selected = "") 
              } else {
                # CASE 2: Manual Mode (Fractions)
                active_manual_level(next_level) # SET ACTIVE MANUAL LEVEL
                
                shinyjs::hide(next_level)
                shinyjs::show(base::paste0("manual_wrapper_", next_level))
                manual_id <- ns(base::paste0("manual_", next_level))
                shinyjs::runjs(sprintf("$('#%s').prop('readonly', true);", manual_id))
                
                target_id_col <- config$mapping[[next_level]]$id_col
                
                # MAP UPDATE: Darker Borders, Lighter Fill
                plot_on_map("map", next_data, session, id_col = target_id_col, 
                            draw = TRUE, 
                            color = "#b35900",    # Darker Orange Border
                            weight = 2,           # Slightly thicker
                            fill_color = "orange", 
                            fill_opacity = 0.2)
                
                map_updated <- TRUE 
              }
            } else {
              active_manual_level(NULL)
              shinyjs::show(next_level)
              shiny::updateSelectInput(session, next_level, choices = c("No subdivisions found" = ""), selected = "")
            }
          } 
          
          if (!map_updated && !is.null(target_row) && nrow(target_row) > 0) {
            plot_on_map("map", target_row, session, draw = TRUE)
          }
          
        }, ignoreInit = TRUE)
      })
    })
    
    # --- 5. Map Clicks (Logic Fix for Re-Selection) ---
    shiny::observeEvent(input$map_shape_click, {
      click <- input$map_shape_click
      if (is.null(click$id)) return() 
      
      # FIX: Use the robust explicit state variable
      active_level <- active_manual_level()
      
      # Fallback: If no manual level is active, try to find the first empty level (for standard map clicking)
      if (is.null(active_level)) {
        current_loc <- selected_location()
        active_level <- names(current_loc)[which(current_loc == "" | is.na(current_loc))[1]]
      }
      
      if (!is.null(active_level) && !is.na(active_level)) {
        # 1. Update UI
        shiny::updateTextInput(session, base::paste0("manual_", active_level), value = click$id)
        update_location(selected_location, active_level, click$id)
        update_location(selected_ids, active_level, click$id)
        
        # 2. Visual Feedback (Highlighter)
        config <- active_config()
        highlight_data <- fetch_level_data(active_level, parent_val = NULL, country_config = config) 
        
        if (!is.null(highlight_data)) {
          target_col <- config$mapping[[active_level]]$id_col
          if (is.null(target_col)) target_col <- "cde"
          
          if (target_col %in% names(highlight_data)) {
            selected_poly <- highlight_data[highlight_data[[target_col]] == click$id, ]
            
            if (nrow(selected_poly) > 0) {
              proxy <- leaflet::leafletProxy("map", session = session)
              if (!is.null(current_highlight_id())) {
                proxy |> leaflet::removeShape(layerId = "highlight_layer")
              }
              
              proxy |> leaflet::addPolygons(
                data = selected_poly,
                layerId = "highlight_layer", 
                color = "cyan",       
                weight = 3,
                fillOpacity = 0.6
              )
              current_highlight_id(click$id)
            }
          }
        }
      }
    })
    
    output$map <- leaflet::renderLeaflet({
      leaflet::leaflet() |> leaflet::addTiles()
    })
    
    base::return(selected_location)
  })
}