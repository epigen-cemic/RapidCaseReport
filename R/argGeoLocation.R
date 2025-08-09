argGeoLocation <- function() {

  provs <- get_info_about("*", "prov")
  dpto <- reactiveVal(get_info_about("*", "dpto", "cde", "00"))
  fracc <- reactiveVal(get_info_about("*", "dpto", "cde", "00"))
  selected_location <- reactiveVal(list(
    province = NULL,
    department = NULL,
    locality = NULL,
    census_fraction = NULL
  ))
  selected_cod_indec <- reactiveVal(NULL)
  
  sidebar <- tagList(
    selectInput("country", "Select Country:",choices = c("Argentina"),selected = "Argentina",
                multiple = FALSE) %>% tagAppendAttributes(disabled = "disabled"),
    selectInput("Province", "Select Province:", choices = c("No information available" = "")),
    selectInput("Department", "Select Department:", choices = c("No information available" = "")),
    selectInput("Locality", "Select Locality:", choices = c("No information available" = "")),
    textInput("Fraction", "Select an Area:", value = "No information available", width = "100%")
    
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

    prov_choices <- unique(provs$nam)

    updateSelectInput(session, "Province", 
                      choices = c("Select a Province" = "", prov_choices))
    
    observeEvent(input$Province, {
      req(input$Province != "")
      localities_shown(FALSE) #reset flag
      
      prov_selected <- provs[provs$nam == input$Province, ]
      selected_cpr(unique(prov_selected$cpr))
      
      cpr_code <- as.character(sprintf("%02s", selected_cpr()))
      dpto(get_info_about("*", "dpto", "cpr", cpr_code))
      
      dpto_names <- unique(dpto()$nam)
      
      updateSelectInput(session, "Department", choices = c("Select a Department:" = "", dpto_names))
      updateSelectInput(session, "Locality", choices = c("Select a Locality:" = ""))
      
      prov_selected <- st_make_valid(prov_selected)
      
      bbox <- st_bbox(prov_selected)
      zoom_level <- get_zoom(bbox)
      prov_centroid <- st_centroid(prov_selected)
      prov_coords <- st_coordinates(prov_centroid)
      
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(data = prov_selected, color = "blue", weight = 2) %>%
        setView(lng = prov_coords[1], lat = prov_coords[2], zoom = zoom_level) %>%
        fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax) 
      
      current_location <- selected_location()  
      current_location$province <- input$Province  
      current_location$department <- ""
      current_location$locality <- ""
      current_location$census_fraction <- ""
      selected_location(current_location) 
    })
    
    observeEvent(input$Department, {
      req(input$Department != "")
      
      dept_selected <- dpto()[
        dpto()$nam == input$Department, ]
      
      selected_cde(unique(dept_selected$cde))

      cde_code <- as.character(sprintf("%05s", selected_cde()))
      fracc(get_info_about("*", "fracc", "cde", cde_code))

      locality_filtered <- open_dataset(here("raw_data", "localities.parquet")) %>%
        filter(cde == cde_code) %>% 
        select(cde, Localidad) %>%
        collect()
      
      updateSelectInput(session, "Locality", choices = c("Select a Locality:" = "", locality_filtered$Localidad))
      
      fracc_filtered <- fracc()[fracc()$cde == selected_cde(), ]
      fracc_names <- unique(fracc_filtered$cfn)
      updateTextInput(session, "Fraction", value = "Select on the map")
      
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(data = fracc_filtered, color = "red", weight = 2, 
                    popup = ~cfn, layerId = ~cod_indec)
      
      dept_selected <- st_make_valid(dept_selected)
      
      bbox <- st_bbox(dept_selected)
      zoom_level <- get_zoom(bbox)
      dept_centroid <- st_centroid(dept_selected)
      dept_coords <- st_coordinates(dept_centroid)
      
      leafletProxy("map") %>%
        setView(lng = dept_coords[1], lat = dept_coords[2], zoom = zoom_level) %>%
        fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax)

      current_location <- selected_location()  
      current_location$department <- input$Department 
      current_location$locality <- ""
      current_location$census_fraction <- ""
      selected_location(current_location) 
      
      localities_shown(TRUE) #start flag
    })
    
    observeEvent(input$Locality, {
      req(input$Locality != "")
      
      current_location <- selected_location()  
      current_location$locality <- input$Locality  
      selected_location(current_location) 
    })
    
    observeEvent(input$map_shape_click, {
      req(localities_shown())
      
      clicked_shape <- input$map_shape_click
      cod_indec_selected <- clicked_shape$id
      
      fracc_selected <- fracc()[as.character(fracc()$cod_indec) == as.character(cod_indec_selected), ]
      
      selected_cod_indec(as.character(sprintf("%07s", cod_indec_selected)))
      
      fracc_selected <- st_make_valid(fracc_selected)
      fraccs_filtered <- fracc()[fracc()$cde == selected_cde(), ]
      
      leafletProxy("map") %>%
        clearShapes() %>%
        addPolygons(data = fraccs_filtered, color = "red", weight = 2, 
                    popup = ~cpr, layerId = ~cod_indec)
      
      fracc_selected <- st_make_valid(fracc_selected)
      
      bbox <- st_bbox(fracc_selected)
      fracc_centroid <- st_centroid(fracc_selected)
      fracc_coords <- st_coordinates(fracc_centroid)
      
      updateTextInput(session, "Fraction", value = paste("Selected area: ", fracc_selected$cfn))
      
      leaflet::leafletProxy("map") %>%
        leaflet::addPolygons(data = fracc_selected,
                             color = "green", weight = 2, popup = ~cfn, layerId = ~cod_indec)
      
      shinyjs::runjs('$("#Fraction").prop("readonly", true);') 
      
      current_location <- selected_location()  
      current_location$census_fraction <- as.character(sprintf("%07s", selected_cod_indec()))
      selected_location(current_location) 
    })
    
    output$map <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        setView(lng = -63.6167, lat = -38.4161, zoom = 5)
    })
    
  }
  return(list(sidebar = sidebar, main = main, server = server, selection = selected_location))
}
