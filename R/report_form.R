#' Case Report UI
#' @param id Character. The module ID.
#' @export
caseReportUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    useShinyjs(),
    tags$head(
      tags$title("Rapid Case Report"),
      tags$link(rel = "stylesheet", type = "text/css", href = "config.css")
    ),

    div(class = "nav-bar",
        div(class = "nav-content",
            div(class = "header-logo-left"),
            div(class = "version-badge", paste("v", app_version))
        )
    ),

    div(class = "hero-section",
        div(class = "hero-content",
            h1(class = "app-title", "Rapid Case Report"),
            div(class = "breadcrumb-text", "Online form for rapid reporting of suspected cases.")
        )
    ),

    div(class = "content-wrapper",
        div(class = "well-custom",
            sidebarLayout(
              sidebarPanel(
                class = "form-sidebar",
                h3("General Information"),
                dateInput(ns("consultation_date"), "Consultation Date:", max = Sys.Date()),
                selectInput(ns("sex"), "Sex:", choices = c("", "Male", "Female", "Other", "Prefer not to say")),
                dateInput(ns("birth_date"), "Birth Date:", max = Sys.Date()),

                h3("Location"),
                geoLocationUI(ns("geo"))$sidebar,

                h3("Symptoms"),
                dateInput(ns("symptom_onset_date"), "Symptom Onset Date:", max = Sys.Date()),
                textAreaInput(ns("symptom_description"), "Symptom Description:", ""),

                h3("Suspected Diagnosis"),
                textAreaInput(ns("suspected_diagnosis"), "Suspected Diagnosis:", ""),

                h3("Professional Information"),
                textInput(ns("email"), "Email:", placeholder = "Enter your email"),
                textInput(ns("institution"), "Institution:", placeholder = "Enter your institution"),

                actionButton(ns("load"), "Submit Report", class = "primary-action")
              ),

              mainPanel(
                div(class = "output-card map-card",
                    h3("Location map"),
                    geoLocationUI(ns("geo"))$main
                ),
                div(class = "output-card",
                    h3("Current session records"),
                    tags$p(
                      class = "small-note",
                      "Confirmed records are saved immediately. Review the confirmation dialog carefully before submitting."
                    ),
                    DT::DTOutput(ns("form_preview")),
                    div(class = "download-actions",
                        downloadButton(ns("download_data"), "Download Current Session CSV")
                    )
                )
              )
            )
        )
    )
  )
}


#' Rapid Report Server
#'
#' @param id Character. The module ID.
#' @param selected_location Reactive. The geographic state from the geoLocation module.
#' @param pool The active database connection pool.
#' @export
caseReportServer <- function(id, selected_location, pool) {
  moduleServer(id, function(input, output, session) {

    form_records <- reactiveVal(data.frame())

    empty_preview <- function() {
      data.frame(
        Consultation = character(0),
        `Birth Date` = character(0),
        Sex = character(0),
        `Level 1` = character(0),
        `Level 2` = character(0),
        `Level 3` = character(0),
        Symptoms = character(0),
        `Submitted At` = character(0),
        check.names = FALSE
      )
    }

    preview_data <- reactive({
      records <- form_records()
      if (is.null(records) || nrow(records) == 0) {
        return(empty_preview())
      }

      df <- records %>%
        dplyr::select(consultation_date, birth_date, sex, level1, level2, level3, symptom_description, submitted_at) %>%
        dplyr::mutate(
          consultation_date = format(as.Date(consultation_date), "%d/%m/%Y"),
          birth_date = format(as.Date(birth_date), "%d/%m/%Y")
        )

      current_country <- selected_location()$country
      mapping_names <- c("Level 1", "Level 2", "Level 3")
      if (!is.null(current_country) && !is.null(geo_config[[current_country]])) {
        cfg <- geo_config[[current_country]]
        keys <- get_mapping_keys(cfg)
        if (length(keys) > 0) {
          mapping_names <- vapply(keys[seq_len(min(3, length(keys)))], function(key) {
            get_level_label(cfg, key)
          }, character(1))
          mapping_names <- c(mapping_names, rep("Level", 3 - length(mapping_names)))[1:3]
        }
      }

      colnames(df) <- c(
        "Consultation",
        "Birth Date",
        "Sex",
        mapping_names[1],
        mapping_names[2],
        mapping_names[3],
        "Symptoms",
        "Submitted At"
      )

      df
    })

    output$form_preview <- DT::renderDT({
      app_datatable(preview_data(), page_length = 8)
    })

    observeEvent(input$load, {
      loc <- selected_location()

      errors <- validate_form_inputs(
        consultation_date = input$consultation_date,
        birth_date = input$birth_date,
        sex = input$sex,
        loc = loc,
        symptom_description = input$symptom_description,
        suspected_diagnosis = input$suspected_diagnosis,
        email = input$email,
        institution = input$institution
      )

      if (length(errors) > 0) {
        showModal(modalDialog(
          title = "Missing or invalid information",
          HTML(paste0("<b>", errors, "</b>", collapse = "<br>")),
          easyClose = TRUE
        ))
        return()
      }

      country_cfg <- geo_config[[loc$country]]
      keys <- get_mapping_keys(country_cfg)
      label_l1 <- if (length(keys) >= 1) get_level_label(country_cfg, keys[[1]]) else "Level 1"
      label_l2 <- if (length(keys) >= 2) get_level_label(country_cfg, keys[[2]]) else "Level 2"
      label_l3 <- if (length(keys) >= 3) get_level_label(country_cfg, keys[[3]]) else "Level 3"

      showModal(modalDialog(
        title = "Confirm Submission",
        HTML(paste0(
          "<h3>Summary of Information</h3>",
          "<b>Consultation Date:</b> ", input$consultation_date, "<br/>",
          "<b>Birth Date:</b> ", input$birth_date, "<br/>",
          "<b>Sex:</b> ", input$sex, "<br/>",
          "<b>Symptoms:</b> ", input$symptom_description, "<br/>",
          "<b>Symptoms Onset Date:</b> ", input$symptom_onset_date, "<br/>",
          "<hr>",
          "<b>Country:</b> ", loc$country, "<br/>",
          "<b>", label_l1, ":</b> ", loc$level1, "<br/>",
          "<b>", label_l2, ":</b> ", loc$level2, "<br/>",
          "<b>", label_l3, " (ID):</b> ", loc$level3, "<br/>",
          "<hr>",
          "<b>Email:</b> ", input$email, "<br/>",
          "<b>Institution:</b> ", input$institution, "<br/><br/>",
          "<em>After confirmation this record is saved and cannot be edited from this form.</em>"
        )),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_modal"), "Confirm")
        )
      ))
    })

    observeEvent(input$confirm_modal, {
      loc <- selected_location()
      new_entry <- format_new_entry(input, loc)

      inserted <- insert_to_db(new_entry, pool)
      if (!isTRUE(inserted)) {
        removeModal()
        showNotification("Submission failed. Please try again.", type = "error")
        return()
      }

      form_records(dplyr::bind_rows(form_records(), new_entry))

      removeModal()
      showNotification("Submission successful.", type = "message")

      updateDateInput(session, "consultation_date", value = Sys.Date())
      updateSelectInput(session, "sex", selected = "")
      updateDateInput(session, "birth_date", value = Sys.Date())
      updateDateInput(session, "symptom_onset_date", value = Sys.Date())
      updateTextAreaInput(session, "symptom_description", value = "")
      updateTextAreaInput(session, "suspected_diagnosis", value = "")
    })

    output$download_data <- downloadHandler(
      filename = function() {
        timestamped_filename("session_records")
      },
      contentType = "text/csv; charset=utf-8",
      content = function(file) {
        data <- form_records()
        if (is.null(data) || nrow(data) == 0) {
          data <- data.frame(
            id_code = character(0),
            consultation_date = character(0),
            sex = character(0),
            birth_date = character(0),
            country = character(0),
            level1 = character(0),
            level2 = character(0),
            level3 = character(0),
            symptom_onset_date = character(0),
            symptom_description = character(0),
            suspected_diagnosis = character(0),
            confirmation_time = character(0),
            submitted_at = character(0),
            email = character(0),
            institution = character(0),
            stringsAsFactors = FALSE
          )
        }
        write_csv_utf8(data, file)
      }
    )
  })
}
