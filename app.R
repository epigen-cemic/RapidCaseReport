
########################################################################################
## WP1.02 "Rumor Form" - Suspected cases rapid report form - v1 edition 10 final ##
########################################################################################



source("R/global.R")

ui <- rumorFormUI("main_form")

server<- function(input, output, session) {
    
  selected_location <- argGeoLocationServer("geo")
  
  initialize_database()
  
  rumorFormServer("main_form", selected_location)
  
  
}

shinyApp(ui, server)



