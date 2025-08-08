reportFormUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),
    
    div(class = "content-wrapper",
        img(src = "PPT_cemic_header.png", class = "header-logo"),
        div(class = "well-custom",
            titlePanel("Rumor Report Form - WP1.02 v20250624"),
            
            sidebarLayout(
              sidebarPanel(
                style = "background-color: #c2c2c2;",
                h3("General Information"),
                dateInput(ns("consultation_date"), "Consultation Date:", max = Sys.Date()),
                selectInput(ns("sex"), "Sex:", choices = c("", "M", "F")),
                dateInput(ns("birth_date"), "Birth Date:", max = Sys.Date()),
                h3("Location"),
                geoModuleUI(ns("geo")),
                h3("Symptoms"),
                dateInput(ns("symptom_onset_date"), "Symptom Onset Date:", max = Sys.Date()),
                textAreaInput(ns("symptom_description"), "Symptom Description:", ""),
                h3("Suspected Diagnosis"),
                textAreaInput(ns("suspected_diagnosis"), "Suspected Diagnosis:", ""),
                textInput(ns("icd10_code"), "ICD-10 Code (e.g., A00, B99):"),
                textInput(ns("email"), "Email:", placeholder = "Enter your email"),
                textInput(ns("institution"), "Institution:", placeholder = "Enter your institution"),
                actionButton(ns("load"), "Load Information")
              ),
              
              mainPanel(
                verbatimTextOutput(ns("submission_status")),
                tableOutput(ns("form_preview")),
                useShinyjs(),
                actionButton(ns("toggle_map"), "Show/Hide Map"),
                div(id = ns("map_container"),
                    div(style = "margin-top: 50px; overflow: visible;",
                        leafletOutput(ns("map"), height = "550px", width = "550px")
                    )
                )
              )
            ),
            
            fluidRow(
              column(
                width = 12,
                style = "margin-top: 50px;",
                downloadButton(ns("download_data"), "Download Reported Cases (CSV)")
              )
            )
        )
    )
  )
}

reportFormServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    generate_id()
    
    output$map <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        setView(lng = -63.6167, lat = -38.4161, zoom = 5)
    })
    
    observeEvent(input$toggle_map, {
      toggle("map_container")  # Toggles visibility
    })
    
    geoModuleServer("geo")
    
  })
}
