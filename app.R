
########################################################################################
## WP1.02 "Rumor Form" - Suspected cases rapid report form - v1 edition 10 final ##
########################################################################################



source("R/global.R")

ui <- rumorFormUI("main_form")

server <- function(input, output, session) {
  
  # Initialize the database connection/files
  initialize_database()
  
  # Start the main form module server.
  # It now handles the geoLocation module internally!
  rumorFormServer("main_form")
  
}

shinyApp(ui, server)


