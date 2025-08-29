
########################################################################################
## WP1.02 "Rumor Form" - Suspected cases rapid report form - v1 edition 10 final ##
########################################################################################


library(shiny)
source("R/global.R")

ui <- fluidPage(
  uiOutput("my_module_ui")
)

server<- function(input, output, session) {
  
  current_lang <- reactiveVal("spanish")  # select desired Language
  
  observeEvent(input$lang, {
    current_lang(input$lang)
  })
  
  translate <- reactive({
    lang <- current_lang()
    function(key) {
      if (!is.null(translations[[lang]]) && key %in% names(translations[[lang]])) {
        translations[[lang]][[key]]} else {key}
    }
  })
  
  output$my_module_ui <- renderUI({
    rumorFormUI("main_form")
  })
  
  selected_location <- argGeoLocationServer("geo", translate)
  
  initialize_database()
  
  rumorFormServer("main_form", selected_location, language = translate)
  
  output$download_data <- downloadHandler(
    filename = function() {
      paste0("rumor_form_records_", Sys.Date(), ".csv")
    },
    content = function(file) {
      data <- form_records()
      if (is.null(data) || nrow(data) == 0) {
        showNotification(tr("No data available to download."), type = "error")
        return(NULL)
      }
      write.csv(data, file, row.names = FALSE)
    }
  )

  output$download_db <- downloadHandler(
    filename = function() {
      paste0("rumor_database_", Sys.Date(), ".dba")
    },
    content = function(file) {
      # Copy the entire SQLite file to the temp file for download
      file.copy(here("data", "your_database.dba"), file)
    }
  )
  
}

shinyApp(ui, server)
