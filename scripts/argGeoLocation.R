argGeoLocation <- function() {

  provs <- st_read(here("data", "prov_indec.gpkg"))
  dpto  <- st_read(here("data", "dpto_indec.gpkg"))
  fraccs <- st_read(here("data", "fracc_indec.gpkg"))
  
  selected_cod_indec <- reactiveVal(NULL)
  
  convert_latin1_to_utf8 <- function(df) {
    char_cols <- names(df)[sapply(df, is.character)]
    for (colname in char_cols) {
      df[[colname]] <- iconv(df[[colname]], from = "latin1", to = "UTF-8", sub = "")
    }
    df
  }
  
  get_zoom_from_bbox <- function(bbox) {
    max_dim <- max(bbox$xmax - bbox$xmin, bbox$ymax - bbox$ymin)
    dplyr::case_when(
      max_dim > 10 ~ 5,
      max_dim > 5 ~ 6,
      max_dim > 2 ~ 7,
      max_dim > 1 ~ 8,
      max_dim > 0.5 ~ 9,
      max_dim > 0.25 ~ 10,
      TRUE ~ 11
    )
  }
  
  sidebar <- tagList(
    selectInput("Province", "Select Province:", choices = c("No information available" = "")),
    selectInput("Department", "Select Department:", choices = c("No information available" = "")),
    selectInput("Locality", "Select Locality:", choices = c("No information available" = ""))
  )
  
  main <- mainPanel(
    leafletOutput("map", height = "600px"),
    tags$style(HTML("
    #map {
      filter: brightness(0.8); 
    }
  "))
  )
  
  server <- function(input, output, session) {
    selected_cpr <- reactiveVal(NULL)
    selected_cde <- reactiveVal(NULL)
    localities_shown <- reactiveVal(FALSE)
    
    provs <- convert_latin1_to_utf8(provs)
    dpto <- convert_latin1_to_utf8(dpto)
    fraccs <- convert_latin1_to_utf8(fraccs)
    
    province_choices <- unique(provs$nam)

    updateSelectInput(session, "Province", 
                      choices = c("Select a Province" = "", province_choices))
    
    observeEvent(input$Province, {
      req(input$Province != "")
      localities_shown(FALSE) #reset flag
      
      prov_selected <- provs[provs$nam == input$Province, ]
      selected_cpr(unique(prov_selected$cpr))
      
      deptos_filtered <- dpto[dpto$cpr == selected_cpr(), ]
      dept_names <- unique(deptos_filtered$nam)
      
      updateSelectInput(session, "Department", choices = c("Select a Department:" = "", dept_names))
      
      prov_selected <- st_make_valid(prov_selected)
      
      bbox <- st_bbox(prov_selected)
      zoom_level <- get_zoom_from_bbox(bbox)
      prov_centroid <- st_centroid(prov_selected)
      prov_coords <- st_coordinates(prov_centroid)
      
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(data = prov_selected, color = "blue", weight = 2) %>%
        setView(lng = prov_coords[1], lat = prov_coords[2], zoom = zoom_level) %>%
        fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax) 
    })
    
    observeEvent(input$Department, {
      req(input$Department != "")
      dept_selected <- dpto[
        dpto$nam == input$Department &
          dpto$cpr == selected_cpr(), ]
      
      selected_cde(unique(dept_selected$cde))
      
      fraccs_filtered <- fraccs[fraccs$cde == selected_cde(), ]
      loc_names <- unique(fraccs_filtered$name)
      
      updateSelectInput(session, "Locality", choices = c("Select on the map" = ""))
      
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(data = fraccs_filtered, color = "red", weight = 2, 
                    popup = ~cpr, layerId = ~cod_indec)
      
      dept_selected <- st_make_valid(dept_selected)
      
      bbox <- st_bbox(dept_selected)
      zoom_level <- get_zoom_from_bbox(bbox)
      dept_centroid <- st_centroid(dept_selected)
      dept_coords <- st_coordinates(dept_centroid)
      
      leafletProxy("map") %>%
        setView(lng = dept_coords[1], lat = dept_coords[2], zoom = zoom_level) %>%
        fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax)
      
      localities_shown(TRUE) #start flag
    })
    
    observeEvent(input$map_shape_click, {
      req(localities_shown())
      
      clicked_shape <- input$map_shape_click
      cod_indec_selected <- clicked_shape$id
      fracc_selected <- fraccs[fraccs$cod_indec == cod_indec_selected, ]
      
      selected_cod_indec(cod_indec_selected)
      
      fraccs_filtered <- fraccs[fraccs$cde == selected_cde(), ]
      
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(data = fraccs_filtered, color = "red", weight = 2, 
                    popup = ~cpr, layerId = ~cod_indec)
      
      fracc_selected <- st_make_valid(fracc_selected)
      
      bbox <- st_bbox(fracc_selected)
      fracc_centroid <- st_centroid(fracc_selected)
      fracc_coords <- st_coordinates(fracc_centroid)
      
      leafletProxy("map") %>%
        addPolygons(data = fracc_selected, color = "green", weight = 2)
    })
    
    output$map <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        setView(lng = -63.6167, lat = -38.4161, zoom = 5)
    })
  }
  
  return(list(sidebar = sidebar, main = main, server = server))
}