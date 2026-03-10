
########################################################################################
## WP1.02 "Rumor Form" - Suspected cases rapid report form - v1 edition 10 final ##
########################################################################################

source("global.R")

ui <- rumorFormUI("form")

server <- function(input, output, session) {
  
  selected_loc <- geoLocationServer("form-geo", geo_config, data_dir)

  rumorFormServer("form", selected_location = selected_loc, pool = db_pool) 
  
}

shinyApp(ui, server)



