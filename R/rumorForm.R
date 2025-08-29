        # =======================
        # ========= UI ==========
        # =======================
rumorFormUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    useShinyjs(),
#    selectInput(ns("lang"), "Language:", choices = c("english", "spanish"), selected = "spanish"),
    
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),
    
    uiOutput(ns("translated_form"))
  )
}

        # =======================
        # ======== Server =======
        # =======================
rumorFormServer <- function(id, selected_location, language) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    output$translated_form <- renderUI({
      tr <- language()
      div(class = "content-wrapper",
          img(src = "PPT_cemic_header.png", class = "header-logo", style = "width: 100%; height: auto; max-width: 900px;"),
          div(class = "well-custom",
              titlePanel(div(style = "text-align: center; margin-bottom: 20px;",
                             tr("Rumor Report Form - WP1.02 v1.10F2"))),
              
              sidebarLayout(
                sidebarPanel(style = "background-color: #c2c2c2;",
                             
                             h3(tr("General Information")),
                             dateInput(ns("consultation_date"), tr("Consultation Date:"), max = Sys.Date()),
                             selectInput(ns("sex"), tr("Sex:"), 
                                         choices = c("", tr("Male"), tr("Female"), tr("Other"), tr("Prefer not to say"))),
                             dateInput(ns("birth_date"), tr("Birth Date:"), max = Sys.Date()),
                             
                             h3(tr("Location")),
                             argGeoLocationUI("geo")$sidebar,
                             
                             h3(tr("Symptoms")),
                             dateInput(ns("symptom_onset_date"), tr("Symptom Onset Date:"), max = Sys.Date()),
                             textAreaInput(ns("symptom_description"), tr("Symptom Description:"), ""),
                             
                             h3(tr("Suspected Diagnosis")),
                             icdAutocompleteUI("icd_module"),
                             
                             h3(tr("Professional's Information")),
                             textInput(ns("email"), "Email:", placeholder = tr("Enter your email")),
                             textInput(ns("institution"), tr("Institution:"), placeholder = tr("Enter your institution")),
                             
                             actionButton(ns("load"), tr("Load Information"))
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
                  downloadButton(ns("download_data"), tr("Download Reported Cases (CSV)"))
              )
          )
      )
    })
    
    form_records <- reactiveVal(data.frame())
    
    selected_codes <- icdAutocompleteServer("icd_module", icd_choices, max_items = 5)
    
    output$codes <- renderPrint({
      selected_codes()
    })
    
    
    observeEvent(input$load, {
      tr <- language()
      errors <- c()
      loc <- selected_location()
      if (input$consultation_date > Sys.Date()) 
        errors <- c(errors, tr("Consultation date can't be in the future."))
      if (input$birth_date > Sys.Date()) 
        errors <- c(errors, tr("Birth date can't be in the future."))
      if (input$birth_date > input$consultation_date) 
        errors <- c(errors, tr("Birth date can't be after consultation date."))
      if (is.null(input$sex) || input$sex == "") {
        errors <- c(errors, tr("Please select a sex."))}
      if (is.null(loc) || any(sapply(loc, function(x) is.null(x) || x == "" || is.na(x)))) {
        errors <- c(errors, tr("You must complete the location."))}
      if (!nzchar(input$symptom_description)) 
        errors <- c(errors, tr("Symptom description is required."))
#      if (!nzchar(input$suspected_diagnosis)) 
#        errors <- c(errors, tr("Suspected diagnosis is required."))
      if (length(selected_codes()) == 0 || selected_codes() == "") {
        errors <- c(errors, tr("ICD-10 code is required."))}
      if (!grepl("^\\S+@\\S+\\.\\S+$", input$email)) 
        errors <- c(errors, tr("Please enter a valid email address."))
      if (!nzchar(input$institution)) 
        errors <- c(errors, tr("Institution is required."))
      
      if (length(errors) > 0) {
        errors <- paste0("<b>", errors, "</b>")
        showModal(modalDialog(
          title = tr("Missing or invalid information"),
          HTML(paste(errors, collapse = "<br>")),
          easyClose = TRUE
        ))
        return()
      }
      
      showModal(modalDialog(
        title = "Confirm Submission",
        HTML(paste0(
          "<b>", tr("Consultation Date:"), "</b> ", input$consultation_date, "<br/>",
          "<b>", tr("Sex:"), "</b> ", input$sex, "<br/>",
          "<b>", tr("Birth Date:"), "</b> ", input$birth_date, "<br/>",
          "<b>", tr("Province:"), "</b> ", loc$province, "<br/>",
          "<b>", tr("Department:"), "</b> ", loc$department, "<br/>",
          "<b>", tr("Locality:"), "</b> ", loc$locality, "<br/>",
          "<b>", tr("Censal Fraction:"), "</b> ", loc$census_fraction, "<br/>",
          "<b>", tr("Symptoms:"), "</b> ", input$symptom_description, "<br/>",
          "<b>", tr("Suspected Diagnosis:"), "</b> ", input$suspected_diagnosis, "<br/>",
          "<b>", tr("ICD-10 Code:"), "</b> ", paste(selected_codes(), collapse = ", "),
          "<b>", tr("Email:"), "</b> ", input$email, "<br/>",
          "<b>", tr("Institution:"), "</b> ", input$institution
        )),
        footer = tagList(
          modalButton(tr("Cancel")),
          actionButton(session$ns("confirm_modal"), tr("Confirm")) 
        )
      ))
    })
    
    observeEvent(input$confirm_modal, {
      selection <- selected_location()
      
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
        title = tr("Submission Successful"),
        tr("Your form has been successfully submitted."),
        easyClose = TRUE
      ))
      
      output$form_preview <- renderTable({
        df <- form_records() %>%
          select(birth_date, sex, consultation_date ,symptom_description, icd10_code) %>%
          mutate(birth_date = format(as.Date(birth_date), "%Y-%m-%d"))
        setNames(df, c(tr("Birth Date"), tr("Sex"), tr("Consultation date"), tr("Symptoms"), tr("ICD-10 Codes")))
      }, bordered = TRUE)
      
      # Reset inputs
      updateDateInput(session, "consultation_date", value = Sys.Date())
      updateSelectInput(session, "sex", selected = "")
      updateDateInput(session, "birth_date", value = Sys.Date())
      updateTextInput(session, "symptom_description", value = "")
      updateTextInput(session, "suspected_diagnosis", value = "")
      updateTextInput(session, "icd10_code", value = "")
    })
    
  })
}

