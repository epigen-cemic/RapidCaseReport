        # =======================
        # ========= UI ==========
        # =======================
argGeoLocationUI <- function(id) {
  ns <- NS(id)
  
  sidebar <- tagList(
    selectInput(ns("country"), "Select Country:",
                choices = c("Argentina"), selected = "Argentina", multiple = FALSE) %>%
      tagAppendAttributes(disabled = "disabled"),
    selectInput(ns("Province"), "Select Province:", choices = c("No information available" = "")),
    selectInput(ns("Department"), "Select Department:", choices = c("No information available" = "")),
    selectInput(ns("Locality"), "Select Locality:", choices = c("No information available" = "")),
    textInput(ns("Fraction"), "Select an Area:", value = "No information available", width = "100%")
  )
  
  main <- mainPanel(
    leafletOutput(ns("map"), height = "600px", width = "100%")
  )
  
  # return as list
  list(
    sidebar = sidebar,
    main = main
  )
}

        # =======================
        # ======== Server =======
        # =======================
argGeoLocationServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    # --- Variable Initialization
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
    selected_cpr <- reactiveVal(NULL)
    selected_cde <- reactiveVal(NULL)
    localities_shown <- reactiveVal(FALSE)
    
    # --- Init Province choices
    prov_choices <- unique(provs$nam)
    updateSelectInput(session, "Province", 
                      choices = c("Select a Province" = "", prov_choices))
    
    
    observeEvent(input$Province, {
      req(input$Province != "")
      localities_shown(FALSE)
      
      prov_selected <- provs[provs$nam == input$Province, ]
      selected_cpr(unique(prov_selected$cpr))
      
      cpr_code <- as.character(sprintf("%02s", selected_cpr()))
      dpto(get_info_about("*", "dpto", "cpr", cpr_code))
      
      dpto_names <- unique(dpto()$nam)
      updateSelectInput(session, "Department", choices = c("Select a Department:" = "", dpto_names))
      updateSelectInput(session, "Locality", choices = c("Select a Locality:" = ""))
      
      plot_on_map("map", prov_selected, session, draw = TRUE)
      update_location(selected_location, "province", input$Province)
    })        # --- Observe Province
    
    
    observeEvent(input$Department, {
      req(input$Department != "")
      
      dept_selected <- dpto()[dpto()$nam == input$Department, ]
      selected_cde(unique(dept_selected$cde))
      
      cde_code <- as.character(sprintf("%05s", selected_cde()))
      fracc(get_info_about("*", "fracc", "cde", cde_code))
      
      locality_filtered <- open_dataset(here("raw_data", "localities.parquet")) %>%
        filter(cde == cde_code) %>% 
        select(cde, Localidad) %>%
        collect()
      
      updateSelectInput(session, "Locality", 
                        choices = c("Select a Locality:" = "", locality_filtered$Localidad))
      
      plot_on_map("map", dept_selected, session)
      plot_fractions("map", fracc(), selected_cde(), NULL, session)
      
      update_location(selected_location, "department", input$Department)
      localities_shown(TRUE)
    })        # --- Observe Department
    
    
    observeEvent(input$Locality, {
      req(input$Locality != "")
      update_location(selected_location, "locality", input$Locality)
    })        # --- Observe Locality
    
    
    observeEvent(input$map_shape_click, {
      req(localities_shown())
      
      clicked_shape <- input$map_shape_click
      cod_indec_selected <- clicked_shape$id
      
      selected_cod_indec(as.character(sprintf("%07s", cod_indec_selected)))
      plot_fractions("map", fracc(), selected_cde(), cod_indec_selected, session)
      
      shinyjs::runjs('$("#Fraction").prop("readonly", true);')
      update_location(selected_location, "census_fraction", selected_cod_indec())
    })        # --- Observe Fraction (click)
    
    
    output$map <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        setView(lng = -63.6167, lat = -38.4161, zoom = 5)
    })      # --- Render Map
    
    # Return the selected location so the app can use it
    return(selected_location)
  })
}
