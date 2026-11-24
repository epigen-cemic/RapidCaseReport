################################################################################
## RapidCaseReport v2.0 - Online form for rapid reporting of suspected cases    ##
################################################################################

source("global.R")

ui <- caseReportUI("form")

#' Run the case-report Shiny server
#'
#' Start the reporting and geographic-selection modules against the initialized data store.
#'
#' @param input Shiny input object for the current module.
#' @param output Shiny output object for the current module.
#' @param session Active Shiny session.
#' @return The Shiny server side-effect result.
#' @keywords internal
server <- function(input, output, session) {
  selected_loc <- geoLocationServer("form-geo", geo_config, data_dir)
  caseReportServer("form", selected_location = selected_loc, pool = db_pool)
}

shinyApp(ui, server)
