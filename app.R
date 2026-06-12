################################################################################
## RapidCaseReport v2.0 - Online form for rapid reporting of suspected cases    ##
################################################################################

source("global.R")

ui <- caseReportUI("form")

server <- function(input, output, session) {
  selected_loc <- geoLocationServer("form-geo", geo_config, data_dir)
  caseReportServer("form", selected_location = selected_loc, pool = db_pool)
}

shinyApp(ui, server)
