#' Rumor Report Form Module UI
#'
#' Generates the user interface for the Rumor Report Form (v1.2). 
#' The layout is divided into a sidebar for data entry (General Info, Location, Symptoms)
#' and a main panel for the map visualization and data preview.
#' 
#' The location section relies on the `geoLocationUI` module to dynamically 
#' render the appropriate administrative levels for the selected country.
#'
#' @param id Character. The module ID used to namespace inputs and outputs.
#'
#' @return A `shiny::fluidPage` object containing the complete form layout.
#' 
#' @importFrom shiny NS fluidPage tags div img titlePanel sidebarLayout sidebarPanel 
#'   h3 dateInput selectInput uiOutput textAreaInput actionButton mainPanel 
#'   verbatimTextOutput tableOutput downloadButton showModal modalDialog
#' @importFrom shinyjs useShinyjs
#' @export
rumorFormUI <- function(id) {
  ns <- shiny::NS(id)
  
  shiny::fluidPage(
    shinyjs::useShinyjs(),
    shiny::tags$head(
      shiny::tags$title("Rumor Report Form"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),
    
    shiny::div(class = "content-wrapper",
               shiny::img(src = "PPT_cemic_header.png", 
                          class = "header-logo", 
                          style = "width: 100%; height: auto; max-width: 900px;"),
               shiny::div(class = "well-custom",
                          shiny::titlePanel(shiny::div(style = "text-align: center; margin-bottom: 20px;",
                                                       "Rumor Report Form - WP1.02 v1.2")),
                          
                          shiny::sidebarLayout(
                            shiny::sidebarPanel(style = "background-color: #c2c2c2;",
                                                
                                                shiny::h3("General Information"),
                                                shiny::dateInput(ns("consultation_date"), "Consultation Date:", max = Sys.Date()),
                                                shiny::selectInput(ns("sex"), "Sex:", 
                                                                   choices = c("", "Male", "Female", "Other", "Prefer not to say")),
                                                shiny::dateInput(ns("birth_date"), "Birth Date:", max = Sys.Date()),
                                                
                                                shiny::h3("Location"),
                                                # DYNAMIC PLACEHOLDER: The geoLocationUI selectors will be injected here
                                                shiny::uiOutput(ns("geo_sidebar_container")),
                                                
                                                shiny::h3("Symptoms"),
                                                shiny::dateInput(ns("symptom_onset_date"), "Symptom Onset Date:", max = Sys.Date()),
                                                shiny::textAreaInput(ns("symptom_description"), "Symptom Description:", ""),
                                                
                                                shiny::h3("Suspected Diagnosis"),
                                                shiny::textAreaInput(ns("suspected_diagnosis"), "Suspected Diagnosis:", ""),
                                                
                                                shiny::h3("Professional's Information"),
                                                shiny::textInput(ns("email"), "Email:", placeholder = "Enter your email"),
                                                shiny::textInput(ns("institution"), "Institution:", placeholder = "Enter your institution"),
                                                
                                                shiny::actionButton(ns("load"), "Load Information")
                            ),
                            
                            shiny::mainPanel(
                              shiny::div(style = "margin-top: 50px; width: 150%; overflow: visible; margin-bottom: 20px;",
                                         # DYNAMIC PLACEHOLDER: The Leaflet map will be injected here
                                         shiny::uiOutput(ns("geo_main_container"))
                              ),
                              
                              shiny::verbatimTextOutput(ns("submission_status")),
                              shiny::div(class = "table-container",
                                         shiny::tableOutput(ns("form_preview"))
                              )
                            )
                          ),
                          shiny::div(style = "margin-top: 10px; text-align: left;",
                                     shiny::downloadButton(ns("download_data"), "Download Reported Cases (CSV)")
                          )
               )
    ),
    shiny::actionButton(ns("download_db"), "Download Database", style = "
      background-color: transparent; 
      color: grey; 
      font-size: 12px; 
      border: none;
      padding: 0;
      cursor: pointer;"),
    shiny::downloadButton(ns("file_download"), "Download Now", style = "display:none;")
  )
}

#' Rumor Report Form Module Server
#'
#' Manages the logic for the Rumor Report Form. It handles:
#' \itemize{
#'   \item Initialization of the `geoLocationServer` module.
#'   \item Dynamic rendering of the geographic UI based on the selected country.
#'   \item Validation of form inputs (dates, required fields, email format).
#'   \item Modal confirmations for user data submission.
#'   \item Saving data to the database and updating the local reactive view.
#'   \item Admin features for downloading the full database.
#' }
#'
#' @param id Character. The module ID used to namespace inputs and outputs.
#'
#' @return A `reactiveVal` containing the dataframe of submitted records.
#' 
#' @importFrom shiny moduleServer reactiveVal renderUI observeEvent req showModal modalDialog removeModal downloadHandler renderTable updateDateInput updateSelectInput updateTextAreaInput
#' @importFrom dplyr bind_rows select mutate
#' @export
rumorFormServer <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    form_records <- shiny::reactiveVal(base::data.frame())
    
    # --- 1. Initialize Geographic Module ---
    selected_location <- geoLocationServer("geo")
    
    # --- 2. Render Geographic UI Components Dynamically ---
    output$geo_sidebar_container <- shiny::renderUI({
      # Initializing with Argentina as default
      geoLocationUI(ns("geo"), ALL_CONFIGS$Argentina)$sidebar
    })
    
    output$geo_main_container <- shiny::renderUI({
      geoLocationUI(ns("geo"), ALL_CONFIGS$Argentina)$main
    })
    
    # --- 3. Form Validation ---
    shiny::observeEvent(input$load, {
      errors <- c()
      loc <- selected_location()
      
      # Date Checks
      if (input$consultation_date > Sys.Date()) 
        errors <- c(errors, "Consultation date can't be in the future.")
      if (input$birth_date > Sys.Date()) 
        errors <- c(errors, "Birth date can't be in the future.")
      if (input$birth_date > input$consultation_date) 
        errors <- c(errors, "Birth date can't be after consultation date.")
      
      # NEW: Symptom Onset Check
      if (input$symptom_onset_date > Sys.Date())
        errors <- c(errors, "Symptom onset date can't be in the future.")
      if (input$symptom_onset_date > input$consultation_date)
        errors <- c(errors, "Symptom onset date can't be after consultation date.")
      
      if (!input$sex %in% c("Male", "Female", "Other", "Prefer not to say")) 
        errors <- c(errors, "Please select a sex.")
      
      # Validate Location Hierarchy
      if (base::is.null(loc) || base::any(base::sapply(loc, function(x) is.null(x) || x == "" || is.na(x)))) {
        errors <- c(errors, "You must complete the location hierarchy.")
      }
      
      if (!base::nzchar(input$symptom_description)) 
        errors <- c(errors, "Symptom description is required.")
      if (!base::nzchar(input$suspected_diagnosis)) 
        errors <- c(errors, "Suspected diagnosis is required.")           
      if (!base::grepl("^\\S+@\\S+\\.\\S+$", input$email)) 
        errors <- c(errors, "Please enter a valid email address.")
      if (!base::nzchar(input$institution)) 
        errors <- c(errors, "Institution is required.")
      
      if (base::length(errors) > 0) {
        errors <- base::paste0("<b>", errors, "</b>")
        shiny::showModal(shiny::modalDialog(
          title = "Missing or invalid information",
          shiny::HTML(base::paste(errors, collapse = "<br>")),
          easyClose = TRUE
        ))
        return()
      }
      
      # Build Dynamic Summary for Confirmation
      location_summary <- base::paste(
        base::sapply(base::names(loc), function(n) {
          base::paste0("<b>", tools::toTitleCase(n), ":</b> ", loc[[n]])
        }),
        collapse = "<br/>"
      )
      
      shiny::showModal(shiny::modalDialog(
        title = "Confirm Submission",
        shiny::HTML(base::paste0(
          "<b>Consultation Date:</b> ", input$consultation_date, "<br/>",
          "<b>Sex:</b> ", input$sex, "<br/>",
          "<b>Birth Date:</b> ", input$birth_date, "<br/>",
          location_summary, "<br/>",
          "<b>Symptom Onset Date:</b> ", input$symptom_onset_date, "<br/>",
          "<b>Symptoms:</b> ", input$symptom_description, "<br/>",
          "<b>Suspected Diagnosis:</b> ", input$suspected_diagnosis, "<br/>",
          "<b>Email:</b> ", input$email, "<br/>",
          "<b>Institution:</b> ", input$institution
        )),
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton(ns("confirm_modal"), "Confirm") 
        )
      ))
    })
    
    # --- 4. Database Submission Logic ---
    shiny::observeEvent(input$confirm_modal, {
      selection <- selected_location()
      config <- ALL_CONFIGS[[selection$country]]
      
      # Base entry with form fields
      new_entry <- base::data.frame(
        id_code = generate_id(),
        consultation_date = base::as.character(input$consultation_date),
        sex = input$sex,
        birth_date = base::as.character(input$birth_date),
        symptom_onset_date = base::as.character(input$symptom_onset_date),
        symptom_description = input$symptom_description,
        suspected_diagnosis = input$suspected_diagnosis,
        confirmation_time = base::as.character(base::Sys.time()),
        email = input$email,
        institution = input$institution,
        stringsAsFactors = FALSE
      )
      
      # Standardized Location Dispatcher
      for (i in 2:base::length(config$levels)) {
        orig_name <- config$levels[i]
        col_name  <- base::paste0("Level", i - 1)
        new_entry[[col_name]] <- selection[[orig_name]]
      }
      
      new_entry$country <- selection$country
      
      # Persistence
      insert_to_db(new_entry)
      form_records(dplyr::bind_rows(form_records(), new_entry))
      
      shiny::removeModal()
      shiny::showModal(shiny::modalDialog(
        title = "Submission Successful",
        "Your form has been successfully submitted.",
        easyClose = TRUE
      ))
      
      # Reset Inputs
      shiny::updateDateInput(session, "consultation_date", value = Sys.Date())
      shiny::updateSelectInput(session, "sex", selected = "")
      shiny::updateDateInput(session, "birth_date", value = Sys.Date())
      shiny::updateDateInput(session, "symptom_onset_date", value = Sys.Date())
      shiny::updateTextAreaInput(session, "symptom_description", value = "")
      shiny::updateTextAreaInput(session, "suspected_diagnosis", value = "")
    })
    
    # --- 5. Download Handlers ---
    output$download_data <- shiny::downloadHandler(
      filename = function() { base::paste0("rumor_form_records_", base::Sys.Date(), ".csv") },
      content = function(file) {
        data <- form_records()
        if (base::is.null(data) || base::nrow(data) == 0) {
          shiny::showNotification("No data available to download.", type = "error")
          return(NULL)
        }
        utils::write.csv(data, file, row.names = FALSE)
      }
    )
    
    # --- 6. Admin & Database Access ---
    shiny::observeEvent(input$download_db, {
      shiny::showModal(shiny::modalDialog(
        title = "Enter your email",
        shiny::textInput(ns("email_input"), "Email:"),
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton(ns("confirm_email"), "Confirm")
        ),
        easyClose = TRUE
      ))
    })
    
    shiny::observeEvent(input$confirm_email, {
      shiny::req(input$email_input)
      email <- input$email_input
      shiny::removeModal()
      
      if (email == base::Sys.getenv("ADMIN_EMAIL")) {
        shiny::showModal(shiny::modalDialog(
          title = "Admin Password",
          shiny::passwordInput(ns("admin_password_input"), "Password:"),
          footer = shiny::tagList(
            shiny::modalButton("Cancel"),
            shiny::actionButton(ns("confirm_password"), "Confirm")
          ),
          easyClose = TRUE
        ))
      } else {
        shiny::showModal(shiny::modalDialog(
          title = "Download Your Data",
          "Click the button below to download your CSV:",
          footer = shiny::downloadButton(ns("file_download_email"), "Download Now"),
          easyClose = TRUE
        ))
      }
    })
    
    shiny::observeEvent(input$confirm_password, {
      shiny::req(input$admin_password_input)
      if (input$admin_password_input == base::Sys.getenv("ADMIN_PASSWORD")) {
        shiny::removeModal()
        shiny::showModal(shiny::modalDialog(
          title = "Download Full Database",
          "Click the button below to download the full database:",
          footer = shiny::downloadButton(ns("file_download_admin"), "Download Now"),
          easyClose = TRUE
        ))
      } else {
        shiny::showModal(shiny::modalDialog(
          title = "Error",
          "Incorrect password.",
          easyClose = TRUE
        ))
      }
    })
    
    output$file_download_email <- shiny::downloadHandler(
      filename = function() { base::paste0("data_", input$email_input, ".csv") },
      content = function(file) { download_email(input$email_input, file) }
    )
    
    output$file_download_admin <- shiny::downloadHandler(
      filename = function() { base::paste0("rumor_database_", base::Sys.Date(), ".dba") },
      content = function(file) { download_admin(file) }
    )
    
    # Preview Table Rendering (FIXED: stats::setNames)
    output$form_preview <- shiny::renderTable({
      df <- form_records()
      if (base::nrow(df) == 0) return(NULL)
      
      df |>
        dplyr::select(birth_date, sex, consultation_date, symptom_description, suspected_diagnosis) |>
        dplyr::mutate(birth_date = base::format(base::as.Date(birth_date), "%Y-%m-%d")) |>
        stats::setNames(c("Birth Date", "Sex", "Consultation date", "Symptoms", "Suspected Diagnosis"))
    }, bordered = TRUE)
    
    base::return(form_records)
  })
}