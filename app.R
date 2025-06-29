
########################################################################################
## WP1.1 "Rumor Form" - Suspected cases rapid report form - v20250624_draft7 ##
########################################################################################

#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#


library(shiny)
library(dplyr)
library(uuid)
library(httr)
library(jsonlite)
library(Rcpp)

# Generate unique ID
generate_id <- function() {
  UUIDgenerate()
}

# Function to query GeoNames API
geonames_search <- function(query, feature_class = NULL, country = NULL) {
  base_url <- "http://api.geonames.org/searchJSON"
  res <- tryCatch({
    GET(base_url, query = list(
      q = query,
      maxRows = 10,
      username = "epigen",
      featureClass = feature_class,
      country = country
    ))
  }, error = function(e) NULL)
  
  if (is.null(res) || http_error(res)) return(NULL)
  
  data <- fromJSON(content(res, as = "text", encoding = "UTF-8"))
  if (!is.null(data$geonames)) {
    choices <- unique(data$geonames$name)
    names(choices) <- choices
    return(choices)
  } else {
    return(NULL)
  }
}

# Generalized geo autocomplete initializer
init_geo_autocomplete <- function(input_id, query_input_id, session, input) {
  observe({
    updateSelectizeInput(session, input_id, server = TRUE, choices = NULL,
      options = list(load = I(sprintf("function(query, callback) {
        if (!query.length) return callback();
        Shiny.setInputValue('%s', query, {priority: 'event'});
      }", query_input_id)))
    )
  })

  observeEvent(input[[query_input_id]], {
    results <- geonames_search(input[[query_input_id]])
    updateSelectizeInput(session, input_id, choices = results, server = TRUE)
  })
}

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background-image: url();
        background-size: cover;
        background-position: top center;
        background-repeat: no-repeat;
        background-attachment: fixed;
        margin: 0;
        padding: 0;
      }

      .content-wrapper {
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        justify-content: flex-start;
        align-items: center;
        padding-top: 180px;
        padding-bottom: 40px;
      }

      .well-custom {
        background-color: rgba(255, 255, 255, 0.9);
        border-radius: 10px;
        padding: 25px;
        max-width: 900px;
        width: 100%;
        box-shadow: 0 0 20px rgba(0,0,0,0.2);
      }

      .shiny-output-error-validation {
        color: red;
        font-weight: bold;
      }
    "))
  ),

  div(class = "content-wrapper",
    img(src = "PPT_cemic_header.png", class = "header-logo", height = "100px"),
    div(class = "well-custom",
      titlePanel("Rumor Report Form - WP1.1 v20250624"),

      sidebarLayout(
        sidebarPanel(
          actionButton("new_case", "Report New Case"),
          hr(),
          h3("General Information"),
          dateInput("consultation_date", "Consultation Date:", max = Sys.Date()),
          selectInput("sex", "Sex:", choices = c("", "M", "F")),
          dateInput("birth_date", "Birth Date:", max = Sys.Date()),
          selectizeInput("residence_country", "Residence Country:", choices = NULL, options = list(placeholder = 'Type to search...')), 
          selectizeInput("residence_province", "Residence Province:", choices = NULL, options = list(placeholder = 'Type to search...')),
          selectizeInput("residence_locality", "Residence Locality:", choices = NULL, options = list(placeholder = 'Type to search...')),
          hr(),
          h3("Symptoms"),
          dateInput("symptom_onset_date", "Symptom Onset Date:", max = Sys.Date()),
          textAreaInput("symptom_description", "Symptom Description:", ""),
          textInput("hpo_codes", "Symptom HPO Codes (comma-separated, format HP:0000000):"),
          hr(),
          h3("Suspected Diagnosis"),
          textAreaInput("suspected_diagnosis", "Suspected Diagnosis:", ""),
          textInput("icd10_code", "ICD-10 Code (e.g., A00, B99):"),
          actionButton("confirm", "Confirm Submission")
        ),

        mainPanel(
          verbatimTextOutput("submission_status"),
          tableOutput("form_preview"),
          downloadButton("download_data", "Download Reported Cases (CSV)")
        )
      )
    )
  )
)

server <- function(input, output, session) {

  form_records <- reactiveVal(data.frame())

  observeEvent(input$new_case, {
    session$userData$case_opened <- Sys.time()
  })

  observeEvent(input$confirm, {
    report_opened <- if (!is.null(session$userData$case_opened)) session$userData$case_opened else Sys.time()

    validate(
      need(input$consultation_date <= Sys.Date(), "Consultation date can't be in the future."),
      need(input$birth_date <= Sys.Date(), "Birth date can't be in the future."),
      need(input$birth_date <= input$consultation_date, "Birth date can't be after consultation date."),
      need(input$symptom_onset_date <= input$consultation_date, "Symptom onset date can't be after consultation date."),
      need(input$sex %in% c("M", "F"), "Please select a sex."),
      need(nzchar(input$residence_country), "Please select a residence country."),
      need(nzchar(input$symptom_description), "Symptom description is required."),
      need(nzchar(input$suspected_diagnosis), "Suspected diagnosis is required."),
      need(grepl("^(HP:\\d{7})(,HP:\\d{7})*$", input$hpo_codes) | input$hpo_codes == "", "Invalid HPO codes format."),
      need(grepl("^[A-Z][0-9]{2}[A-Z0-9]?$", input$icd10_code) | input$icd10_code == "", "Invalid ICD-10 code format.")
    )

    new_entry <- data.frame(
      id_code = generate_id(),
      report_opened = report_opened,
      consultation_date = input$consultation_date,
      sex = input$sex,
      birth_date = input$birth_date,
      residence_country = input$residence_country,
      residence_province = input$residence_province,
      residence_locality = input$residence_locality,
      symptom_onset_date = input$symptom_onset_date,
      symptom_description = input$symptom_description,
      hpo_codes = input$hpo_codes,
      suspected_diagnosis = input$suspected_diagnosis,
      icd10_code = input$icd10_code,
      confirmation_time = Sys.time(),
      stringsAsFactors = FALSE
    )

    form_records(bind_rows(form_records(), new_entry))

    output$submission_status <- renderPrint({
      cat("Form successfully submitted. Generated ID:", new_entry$id_code)
    })

    output$form_preview <- renderTable({
      form_records()
    })

    updateTextAreaInput(session, "symptom_description", value = "")
    updateTextAreaInput(session, "suspected_diagnosis", value = "")
    updateTextInput(session, "hpo_codes", value = "")
    updateTextInput(session, "icd10_code", value = "")
  })

  output$download_data <- downloadHandler(
    filename = function() {
      paste0("rumor_form_records_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(form_records(), file, row.names = FALSE)
    }
  )

  init_geo_autocomplete("residence_country", "country_query", session, input)
  init_geo_autocomplete("residence_province", "province_query", session, input)
  init_geo_autocomplete("residence_locality", "locality_query", session, input)
}

shinyApp(ui = ui, server = server)
