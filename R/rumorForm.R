        # =======================
        # ========= UI ==========
        # =======================
rumorFormUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    useShinyjs(),
    tags$head(
      tags$title("Rumor Report Form"),
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),

    div(class = "content-wrapper",
        img(src = "PPT_cemic_header.png", class = "header-logo", style = "width: 100%; height: auto; max-width: 900px;"),
        div(class = "well-custom",
            titlePanel(div(style = "text-align: center; margin-bottom: 20px;",
                           "Rumor Report Form - WP1.02 v1.2")),
            
            sidebarLayout(
              sidebarPanel(style = "background-color: #c2c2c2;",
                           
                           h3("General Information"),
                           dateInput(ns("consultation_date"), "Consultation Date:", max = Sys.Date()),
                           selectInput(ns("sex"), "Sex:", choices = c("", "Male", "Female", "Other", "Prefer not to say")),
                           dateInput(ns("birth_date"), "Birth Date:", max = Sys.Date()),
                           
                           h3("Location"),
                           argGeoLocationUI("geo")$sidebar,
                           
                           h3("Symptoms"),
                           dateInput(ns("symptom_onset_date"), "Symptom Onset Date:", max = Sys.Date()),
                           textAreaInput(ns("symptom_description"), "Symptom Description:", ""),
                           
                           h3("Suspected Diagnosis"),
                           textAreaInput(ns("suspected_diagnosis"), "Suspected Diagnosis:", ""),
                           
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
    actionButton(ns("download_db"), "Download Database", style = "
      background-color: transparent; 
      color: grey; 
      font-size: 12px; 
      border: none;
      padding: 0;
      cursor: pointer;"),
    downloadButton(ns("file_download"), "Download Now", style = "display:none;")
  )
}

        # =======================
        # ======== Server =======
        # =======================
rumorFormServer <- function(id, selected_location) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
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
          "<b>Country:</b> ", loc$country, "<br/>",
          "<b>Province:</b> ", loc$province, "<br/>",
          "<b>Department:</b> ", loc$department, "<br/>",
          "<b>Locality:</b> ", loc$locality, "<br/>",
          "<b>Censal Fraction:</b> ", loc$census_fraction, "<br/>",
          "<b>Symptoms:</b> ", input$symptom_description, "<br/>",
          "<b>Suspected Diagnosis:</b> ", input$suspected_diagnosis, "<br/>",
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
        country = selection$country,
        province = selection$province,
        department = selection$department,
        locality = selection$locality,
        censal_fraction = selection$census_fraction,
        symptom_onset_date = as.character(input$symptom_onset_date),
        symptom_description = input$symptom_description,
        suspected_diagnosis = input$suspected_diagnosis,
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
          select(birth_date, sex, consultation_date ,symptom_description, suspected_diagnosis) %>%
          mutate(birth_date = format(as.Date(birth_date), "%Y-%m-%d"))
        setNames(df, c("Birth Date", "Sex", "Consultation date", "Symptoms", "Suspected Diagnosis"))
      }, bordered = TRUE)
      
      # Reset inputs
      updateDateInput(session, "consultation_date", value = Sys.Date())
      updateTextInput(session, "sex", value = "")
      updateDateInput(session, "birth_date", value = Sys.Date())
      updateTextInput(session, "symptom_description", value = "")
      updateTextInput(session, "suspected_diagnosis", value = "")
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
  
  observeEvent(input$download_db, {
    showModal(modalDialog(
      title = "Enter your email",
      textInput(ns("email_input"), "Email:"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton(ns("confirm_email"), "Confirm")
      ),
      easyClose = TRUE
    ))
  })
  
  observeEvent(input$confirm_email, {
    req(input$email_input)
    email <- input$email_input
    removeModal()
    
    if (email == Sys.getenv("ADMIN_EMAIL")) {
      showModal(modalDialog(
        title = "Admin Password",
        passwordInput(ns("admin_password_input"), "Password:"),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_password"), "Confirm")
        ),
        easyClose = TRUE
      ))
    } else {
      showModal(modalDialog(
        title = "Download Your Data",
        "Click the button below to download your CSV:",
        footer = downloadButton(ns("file_download"), "Download Now"),
        easyClose = TRUE
      ))
      temp_file <- tempfile(fileext = ".csv")
      download_email(email, temp_file)
      output$file_download <- downloadHandler(
        filename = paste0("data_", email, ".csv"),
        content = function(file) file.copy(temp_file, file)
      )
    }
  })
  
  observeEvent(input$confirm_password, {
    req(input$admin_password_input)
    password <- input$admin_password_input
    removeModal()
    
    if (password == Sys.getenv("ADMIN_PASSWORD")) {
      showModal(modalDialog(
        title = "Download Full Database",
        "Click the button below to download the full database:",
        footer = downloadButton(ns("file_download"), "Download Now"),
        easyClose = TRUE
      ))
      temp_file <- tempfile(fileext = ".dba")
      download_admin(temp_file)
      output$file_download <- downloadHandler(
        filename = paste0("rumor_database_", Sys.Date(), ".dba"),
        content = function(file) {
          file.copy(temp_file, file, overwrite = TRUE)
        }
      )
      
    } else {
      showModal(modalDialog(
        title = "Error",
        "Incorrect password.",
        easyClose = TRUE
      ))
    }
  })

  output$file_download <- downloadHandler(
    filename = function() {
      if (input$user_type == "admin") {
        paste0("rumor_database_", Sys.Date(), ".dba")}
      else {paste0("data_", input$email, ".csv")}
    },
    content = function(file) {
      if (input$user_type == "admin") {download_admin(file)}
      else {download_email(input$email, file)}
    }
  )


  })
}
