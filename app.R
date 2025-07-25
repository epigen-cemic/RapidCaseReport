
########################################################################################
## WP1.02 "Rumor Form" - Suspected cases rapid report form - v20250624_draft7 ##
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


# Load scripts

source("scripts/geoLocation.R")
source("scripts/databaseInit.R")
source("scripts/databaseLoad.R")


# Generate unique ID
generate_id <- function() {
  UUIDgenerate()
}

geoLocation <- geoLocation()

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background-image: url();
        background-size: cover;
        background-position: top center;
        background-repeat: no-repeat;
        background-attachment: fixed;
        background-color: #b8c1c8;
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
        background-color: rgba(150, 179, 201, 0.4);
        border-radius: 0px;
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
    img(src = "PPT_cemic_header.png", class = "header-logo", height = "100px", width = "900px"),
    div(class = "well-custom",
      titlePanel("Rumor Report Form - WP1.02 v20250624"),

      sidebarLayout(
        sidebarPanel(style = "background-color: #c2c2c2;",
            h3("General Information"),
            dateInput("consultation_date", "Consultation Date:", max = Sys.Date()),
            selectInput("sex", "Sex:", choices = c("", "M", "F")),
            dateInput("birth_date", "Birth Date:", max = Sys.Date()),
            h3("Location"),
            (geoLocation$sidebar),
            h3("Suspected Diagnosis"),
            textAreaInput("suspected_diagnosis", "Suspected Diagnosis:", ""),
            textInput("icd10_code", "ICD-10 Code (e.g., A00, B99):"),
            textInput("email", "Email:", placeholder = "Enter your email"),
            textInput("institution", "Institution:", placeholder = "Enter your institution"),
            actionButton("load", "Load Information")
          ),
        
          mainPanel(
            verbatimTextOutput("submission_status"),
            tableOutput("form_preview"),
          
            div(style = "margin-top: 50px; width: 150%; overflow: visible;",
                geoLocation$main
            ),
          
            div(style = "margin-top: 1050px; text-align: center;",
                downloadButton("download_data", "Download Reported Cases (CSV)")
            )
          )
          )
      )
    )
  )


server<- function(input, output, session) {
  geoLocation$server(input, output, session)
  session$userData$show_census_info <- reactiveVal(FALSE)
  initialize_database("data/Dummy_database.dba")
  form_records <- reactiveVal(data.frame())
  
  observeEvent(input$load, {
    validate(
      need(input$consultation_date <= Sys.Date(), "Consultation date can't be in the future."),
      need(input$birth_date <= Sys.Date(), "Birth date can't be in the future."),
      need(input$birth_date <= input$consultation_date, "Birth date can't be after consultation date."),
      need(input$sex %in% c("M", "F"), "Please select a sex."),
      need(!is.null(geoLocation$selection()), "You must complete the location."),
      need(nzchar(input$suspected_diagnosis), "Suspected diagnosis is required."),
      need(grepl("^[A-Z][0-9]{2}[A-Z0-9]?$", input$icd10_code) | input$icd10_code == "", "Invalid ICD-10 code format."),
      need(grepl("^\\S+@\\S+\\.\\S+$", input$email), "Please enter a valid email address."),
      need(nzchar(input$institution), "Institution is required.")
    )
    selection <- geoLocation$selection()
    showModal(modalDialog(
      title = "Confirm Submission",
      paste("Consultation Date:", input$consultation_date, "\n",
            "Sex:", input$sex, "\n",
            "Birth Date:", input$birth_date, "\n",
            "Country:", selection$country, "\n",
            "Province:", selection$province, "\n",
            "Department:", selection$department, "\n",
            "Locality:", selection$locality, "\n",
            "Suspected Diagnosis:", input$suspected_diagnosis, "\n",
            "ICD-10 Code:", input$icd10_code, "\n",
            "Email:", input$email, "\n",
            "Institution:", input$institution),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_modal", "Confirm")
      )
    ))
  })

  observeEvent(input$confirm_modal, {
    selection <- geoLocation$selection()
    new_entry <- data.frame(
      id_code = generate_id(),
      consultation_date = input$consultation_date,
      sex = input$sex,
      birth_date = input$birth_date,
      selection_Country = selection$country,
      selection_province = selection$province,
      selection_department = selection$department,
      selection_locality = selection$locality,
      suspected_diagnosis = input$suspected_diagnosis,
      icd10_code = input$icd10_code,
      email = input$email,
      institution = input$institution,
      stringsAsFactors = FALSE
    )

    insert_to_db(new_entry)
    removeModal()
    output$submission_status <- renderPrint({
      cat("Form successfully submitted. Generated ID:", new_entry$id_code)
    })
    form_records(bind_rows(form_records(), new_entry))
    
    output$form_preview <- renderTable({
      form_records()
    })
  })
  output$download_data <- downloadHandler(
    filename = function() {
      paste0("rumor_form_records_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(form_records(), file, row.names = FALSE)
    }
  )


}

shinyApp(ui, server)
