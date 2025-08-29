        # =======================
        # ========= UI ==========
        # =======================

argGeoLocationUI <- function(id) {
  ns <- NS(id)
  
  sidebar <- tagList(
    selectInput(ns("country"), "Select Country:",
                choices = c("Argentina"), selected = "Argentina", multiple = FALSE) %>%
      tagAppendAttributes(disabled = "disabled"),
    uiOutput(ns("location_ui"))
  )
  
  main <- mainPanel(
    leafletOutput(ns("map"), height = "600px", width = "100%")
  )
  
  list(sidebar = sidebar, main = main)
}


        # =======================
        # ======== Server =======
        # =======================
argGeoLocationServer <- function(id, translate) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
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
    
    # --- Render all location inputs dynamically
    output$location_ui <- renderUI({
      tr <- translate()  # reactive translation function
      
      prov_choices <- c("" = tr("No information available"), unique(provs$nam))
      dpto_choices <- c("" = tr("No information available"))
      loc_choices  <- c("" = tr("No information available"))
      
      tagList(
        selectInput(ns("Province"), tr("Select a Province:"), choices = prov_choices),
        selectInput(ns("Department"), tr("Select a Department:"), choices = dpto_choices),
        selectInput(ns("Locality"), tr("Select a Locality:"), choices = loc_choices),
        textInput(ns("Fraction"), tr("Select an Area:"), value = tr("No information available"), width = "100%")
      )
    })
    
    # --- Observe Province selection
    observeEvent(input$Province, {
      req(input$Province != "")
      localities_shown(FALSE)
      
      prov_selected <- provs[provs$nam == input$Province, ]
      selected_cpr(unique(prov_selected$cpr))
      
      cpr_code <- sprintf("%02s", selected_cpr())
      dpto(get_info_about("*", "dpto", "cpr", cpr_code))
      
      # update Department choices inside renderUI by invalidating it
      isolate({
        dpto_names <- c("" = translate()("No information available"), unique(dpto()$nam))
        updateSelectInput(session, "Department", choices = dpto_names, selected = "")
        updateSelectInput(session, "Locality", choices = c("" = translate()("No information available")), selected = "")
      })
      
      plot_on_map("map", prov_selected, session, draw = TRUE)
      update_location(selected_location, "province", input$Province)
    })
    
    # --- Observe Department selection
    observeEvent(input$Department, {
      req(input$Department != "")
      
      dept_selected <- dpto()[dpto()$nam == input$Department, ]
      selected_cde(unique(dept_selected$cde))
      
      cde_code <- sprintf("%05s", selected_cde())
      fracc(get_info_about("*", "fracc", "cde", cde_code))
      
      locality_filtered <- open_dataset(here("raw_data", "localities.parquet")) %>%
        filter(cde == cde_code) %>% select(cde, Localidad) %>% collect()
      
      # Update Locality selectInput
      loc_choices <- c("" = translate()("No information available"), locality_filtered$Localidad)
      updateSelectInput(session, "Locality", choices = loc_choices, selected = "")
      
      plot_on_map("map", dept_selected, session)
      plot_fractions("map", fracc(), selected_cde(), NULL, session)
      
      update_location(selected_location, "department", input$Department)
      localities_shown(TRUE)
    })
    
    # --- Observe Locality selection
    observeEvent(input$Locality, {
      req(input$Locality != "")
      update_location(selected_location, "locality", input$Locality)
    })
    
    # --- Observe map click for Fraction
    observeEvent(input$map_shape_click, {
      req(localities_shown())
      clicked_shape <- input$map_shape_click
      cod_indec_selected <- clicked_shape$id
      selected_cod_indec(sprintf("%07s", cod_indec_selected))
      
      plot_fractions("map", fracc(), selected_cde(), cod_indec_selected, session)
      shinyjs::runjs('$("#Fraction").prop("readonly", true);')
      update_location(selected_location, "census_fraction", selected_cod_indec())
    })
    
    # --- Render map
    output$map <- renderLeaflet({
      leaflet() %>% addTiles() %>% setView(lng = -63.6167, lat = -38.4161, zoom = 5)
    })
    
    # Return reactive selected_location
    return(selected_location)
  })
}
