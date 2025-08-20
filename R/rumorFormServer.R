rumorFormServer <- function(id, selected_location) {
  moduleServer(id, function(input, output, session) {
    
    form_records <- reactiveVal(data.frame())
    
    observeEvent(input$load, {
      errors <- c()
      loc <- selected_location()
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
      #    if (input$icd10_code == "") {                                  # -----------------------------------
      #      errors <- c(errors, "ICD-10 code is required.")}             # Not implemented until autocomplete
      #    if (!grepl("^[A-Z][0-9]{2}[A-Z0-9]?$", input$icd10_code)) {    # is finished
      #      errors <- c(errors, "Invalid ICD-10 code format.")}          # -----------------------------------
      if (!grepl("^\\S+@\\S+\\.\\S+$", input$email)) 
        errors <- c(errors, "Please enter a valid email address.")
      if (!nzchar(input$institution)) 
        errors <- c(errors, "Institution is required.")
      
      if (length(errors) > 0) {
        errors <- paste0("<b>", errors, "</b>")
        showModal(modalDialog(
          title = "Missing or invalid information",
          HTML(paste(errors, collapse = "<br>")),
          easyClose = TRUE
        ))
        return()
      }
      
      showModal(modalDialog(
        title = "Confirm Submission",
        HTML(paste0(
          "<b>Consultation Date:</b> ", input$consultation_date, "<br/>",
          "<b>Sex:</b> ", input$sex, "<br/>",
          "<b>Birth Date:</b> ", input$birth_date, "<br/>",
          "<b>Province:</b> ", loc$province, "<br/>",
          "<b>Department:</b> ", loc$department, "<br/>",
          "<b>Locality:</b> ", loc$locality, "<br/>",
          "<b>Censal Fraction:</b> ", loc$census_fraction, "<br/>",
          "<b>Symptoms:</b> ", input$symptom_description, "<br/>",
          "<b>Suspected Diagnosis:</b> ", input$suspected_diagnosis, "<br/>",
          "<b>ICD-10 Code:</b> ", input$icd10_code, "<br/>",
          "<b>Email:</b> ", input$email, "<br/>",
          "<b>Institution:</b> ", input$institution
        )),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_modal"), "Confirm") 
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
        title = "Submission Successful",
        "Your form has been successfully submitted.",
        easyClose = TRUE
      ))
      
      output$form_preview <- renderTable({
        df <- form_records() %>%
          select(birth_date, sex, symptom_description, id_code) %>%
          mutate(birth_date = format(as.Date(birth_date), "%Y-%m-%d"))
        setNames(df, c("Birth Date", "Sex", "Symptoms", "ID Code"))
      }, bordered = TRUE)
      
      # Reset inputs
      updateDateInput(session, "consultation_date", value = Sys.Date())
      updateTextInput(session, "sex", value = "")
      updateDateInput(session, "birth_date", value = Sys.Date())
      updateTextInput(session, "symptom_description", value = "")
      updateTextInput(session, "suspected_diagnosis", value = "")
      updateTextInput(session, "icd10_code", value = "")
    })
    
  })
}

