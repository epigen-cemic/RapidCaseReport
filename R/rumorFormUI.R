rumorFormUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    useShinyjs(),
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),
    div(class = "content-wrapper",
        img(src = "PPT_cemic_header.png", class = "header-logo", style = "width: 100%; height: auto; max-width: 900px;"),
        div(class = "well-custom",
            titlePanel(div(style = "text-align: center; margin-bottom: 20px;",
                           "Rumor Report Form - WP1.02 v1.10F2")),
            
            sidebarLayout(
              sidebarPanel(style = "background-color: #c2c2c2;",
                           
                           h3("General Information"),
                           dateInput(ns("consultation_date"), "Consultation Date:", max = Sys.Date()),
                           selectInput(ns("sex"), "Sex:", choices = c("", "Male", "Female", "Other", "Prefer not to say")),
                           dateInput(ns("birth_date"), "Birth Date:", max = Sys.Date()),
                           
                           h3("Location"),
                           argGeoLocationUI("geo")$sidebar,  # internal module, keep original ID
                           
                           h3("Symptoms"),
                           dateInput(ns("symptom_onset_date"), "Symptom Onset Date:", max = Sys.Date()),
                           textAreaInput(ns("symptom_description"), "Symptom Description:", ""),
                           
                           h3("Suspected Diagnosis"),
                           textAreaInput(ns("suspected_diagnosis"), "Suspected Diagnosis:", ""),
                           textInput(ns("icd10_code"), "ICD-10 Code (e.g., A00, B99):"),
                           
                           h3("Professional's Information"),
                           textInput(ns("email"), "Email:", placeholder = "Enter your email"),
                           textInput(ns("institution"), "Institution:", placeholder = "Enter your institution"),
                           
                           actionButton(ns("load"), "Load Information")
              ),
              
              mainPanel(
                div(style = "margin-top: 50px; width: 150%; overflow: visible; margin-bottom: 20px;",
                    argGeoLocationUI("geo")$main
                ),
                
                verbatimTextOutput(ns("submission_status")),
                div(class = "table-container",
                    tableOutput(ns("form_preview"))
                )
              )
            ),
            div(style = "margin-top: 10px; text-align: left;",
                downloadButton(ns("download_data"), "Download Reported Cases (CSV)")
            )
        )
    ),
    downloadButton(ns("download_db"), "Download Database", style = "
      background-color: transparent; 
      color: grey; 
      font-size: 12px; 
      border: none;
      padding: 0;
      cursor: pointer;")
  )
}
