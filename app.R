
########################################################################################
## WP1.02 "Rumor Form" - Suspected cases rapid report form - v1 edition 10 final ##
########################################################################################


library(shiny)
source("R/global.R")



ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),
  div(class = "content-wrapper",
    img(src = "PPT_cemic_header.png", class = "header-logo", height = "100px", width = "900px"),
    div(class = "well-custom",
      titlePanel("Rumor Report Form - WP1.02 v20250624"),

      sidebarLayout(
        sidebarPanel(style = "background-color: #c2c2c2;",
            h3("General Information"),
            dateInput("consultation_date", "Consultation Date:", max = Sys.Date()),
            selectInput("sex", "Sex:", choices = c("", "Male", "Female", "Other", "Prefer not to say")),
            dateInput("birth_date", "Birth Date:", max = Sys.Date()),
            h3("Location"),
            (argGeoLocation$sidebar),
            h3("Symptoms"),
            dateInput("symptom_onset_date", "Symptom Onset Date:", max = Sys.Date()),
            textAreaInput("symptom_description", "Symptom Description:", ""),
            h3("Suspected Diagnosis"),
            textAreaInput("suspected_diagnosis", "Suspected Diagnosis:", ""),
            textInput("icd10_code", "ICD-10 Code (e.g., A00, B99):"),
            textInput("email", "Email:", placeholder = "Enter your email"),
            textInput("institution", "Institution:", placeholder = "Enter your institution"),
            actionButton("load", "Load Information")
          ),
        
          mainPanel(
            div(style = "margin-top: 50px; width: 150%; overflow: visible;",
                argGeoLocation$main
            ),
            verbatimTextOutput("submission_status"),
            tableOutput("form_preview")
          )
        ),
      div(style = "margin-top: 10px; text-align: left;",
          downloadButton("download_data", "Download Reported Cases (CSV)")
      )
      )
    )
  )
)


server<- function(input, output, session) {
  argGeoLocation$server(input, output, session)
  form_records <- reactiveVal(data.frame())
  
  observeEvent(input$load, {
    errors <- c()
    loc <- argGeoLocation$selection()
    if (input$consultation_date > Sys.Date()) 
      errors <- c(errors, "Consultation date can't be in the future.")
    if (input$birth_date > Sys.Date()) 
      errors <- c(errors, "Birth date can't be in the future.")
    if (input$birth_date > input$consultation_date) 
      errors <- c(errors, "Birth date can't be after consultation date.")
    if (!input$sex %in% c("Male", "Female", "Other", "Prefer not to say")) 
      errors <- c(errors, "Please select a sex.")
    if (is.null(loc) || any(sapply(loc, function(x) is.null(x) || x == "" || is.na(x)))) {
      errors <- c(errors, "You must complete the location.")}
    if (!nzchar(input$symptom_description)) 
      errors <- c(errors, "Symptom description is required.")
    if (!nzchar(input$suspected_diagnosis)) 
      errors <- c(errors, "Suspected diagnosis is required.")
    if (input$icd10_code == "") {
      errors <- c(errors, "ICD-10 code is required.")}
    if (!grepl("^[A-Z][0-9]{2}[A-Z0-9]?$", input$icd10_code)) {
      errors <- c(errors, "Invalid ICD-10 code format.")}
    if (!grepl("^\\S+@\\S+\\.\\S+$", input$email)) 
      errors <- c(errors, "Please enter a valid email address.")
    if (!nzchar(input$institution)) 
      errors <- c(errors, "Institution is required.")
    
    if (length(errors) > 0) {
      showModal(modalDialog(
        title = "Missing or invalid information",
        HTML(paste(errors, collapse = "<br>")),
        easyClose = TRUE
      ))
      return()
    }
    
    selection <- argGeoLocation$selection()
    if (is.null(selection)) {
      showModal(modalDialog(
        title = "Missing Location Information",
        "Please complete the location information.",
        easyClose = TRUE
      ))
      return()  # Stop if location is missing
    }
    
    showModal(modalDialog(
      title = "Confirm Submission",
      paste("Consultation Date:", input$consultation_date, "\n",
            "Sex:", input$sex, "\n",
            "Birth Date:", input$birth_date, "\n",
            "Province", selection$province, "\n",
            "Department", selection$department, "\n",
            "Locality", selection$locality, "\n",
            "Censal Fraction", selection$census_fraction, "\n",
            "Symptoms: ", input$symptom_description, "\n",
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
  initialize_database()
  
  observeEvent(input$confirm_modal, {
    selection <- argGeoLocation$selection()

    new_entry <- data.frame(
      id_code = generate_id(),
      consultation_date = as.character(input$consultation_date),
      sex = input$sex,
      birth_date = as.character(input$birth_date),
      province = selection$province,
      department = selection$department,
      locality = selection$locality,
      censal_fraction = selection$census_fraction,
      symptom_onset_date = as.character(input$symptom_onset_date),
      symptom_description = input$symptom_description,
      suspected_diagnosis = input$suspected_diagnosis,
      icd10_code = input$icd10_code,
      confirmation_time = as.character(Sys.time()),
      email = input$email,
      institution = input$institution,
      stringsAsFactors = FALSE
    )
    insert_to_db(new_entry)
  
    form_records(bind_rows(form_records(), new_entry))
    
    removeModal()
    showModal(modalDialog(
      title = "Submission Successful",
      "Your form has been successfully submitted.",
      easyClose = TRUE
    ))
    
    output$form_preview <- renderTable({
      df <- form_records() %>%
        select(birth_date, sex, symptom_description, id_code)%>%
        mutate(birth_date = format(as.Date(birth_date), "%Y-%m-%d"))
      setNames(df,
               c("Birth Date", "Sex", "Symptoms", "ID Code"))
    })
    
    updateDateInput(session, "consultation_date", value = Sys.Date())
    updateTextInput(session, "sex", value = "")
    updateDateInput(session, "birth_date", value = Sys.Date())
    updateTextInput(session, "symptom_description", value = "")
    updateTextInput(session, "suspected_diagnosis", value = "")
    updateTextInput(session, "icd10_code", value = "")
  })
  

  
  output$download_data <- downloadHandler(
    filename = function() {
      paste0("rumor_form_records_", Sys.Date(), ".csv")
    },
    content = function(file) {
      data <- form_records()
      if (is.null(data) || nrow(data) == 0) {
        showNotification("No data available to download.", type = "error")
        return(NULL)
      }
      write.csv(data, file, row.names = FALSE)
    }
  )


}

shinyApp(ui, server)
