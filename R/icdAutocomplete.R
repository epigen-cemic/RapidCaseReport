        # =======================
        # ========= UI ==========
        # =======================
icdAutocompleteUI <- function(id, label = "Ingrese un Diagnóstico:") {
  ns <- NS(id)
  tagList(
    selectizeInput(
      ns("icd_input"),
      label,
      choices = NULL,
      options = list(
        placeholder = 'Ingrese un Diagnóstico...',
        maxItems = 1,
        create = FALSE
      )
    ),
    uiOutput(ns("selected_ui")),
    div(
      id = ns("selected_display"),
      style = "width: 100%; min-height: 100px; border: 1px solid #ccc;
        padding: 6px; background-color: #f9f9f9; white-space: pre-wrap;")
  )
}

        # =======================
        # ======== Server =======
        # =======================
icdAutocompleteServer <- function(id, icd_choices, max_items = 5) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    selected_codes <- reactiveVal(character(0))
    
    icd_table <- get_icd_table()
    icd_choices <- setNames(icd_table$code, icd_table$description)
    
    updateSelectizeInput(session, "icd_input", choices = icd_choices, server = TRUE)
    
    
    observeEvent(input$icd_input, {
      if (length(selected_codes()) < max_items && input$icd_input != "") {
        selected_codes(unique(c(selected_codes(), input$icd_input)))
      }
      updateSelectizeInput(session, "icd_input", selected = character(0))
    })
    

    output$selected_ui <- renderUI({
      tags$div(
        lapply(selected_codes(), function(code) {
          desc <- names(icd_choices)[icd_choices == code]
          fluidRow(
            column(8, tags$div(desc, style = "color: black;")),
            column(4, actionButton(
              ns(paste0("remove_", code)),
              label = HTML("&times;"),
              class = "btn-xs",
              style = "
            background-color: transparent;
            color: grey;
            border: none;
            padding: 0;
            font-size: 16px;
            line-height: 1;
          "
            ))
          )
        })
      )
    })
    
    observe({
      lapply(selected_codes(), function(code) {
        btn <- paste0("remove_", code)
        observeEvent(input[[btn]], {
          selected_codes(setdiff(selected_codes(), code))
        }, ignoreInit = TRUE, once = FALSE)
      })
    })
    
    observe({
      descs <- names(icd_choices)[icd_choices %in% selected_codes()]
      output$selected_display <- renderUI({
        desc_text <- paste(descs, collapse = "\n")
        HTML(desc_text)
      })
    })
    
    return(selected_codes)
  })
}