#' Dynamic Geo-Location UI Module
#'
#' Creates the user interface components for the dynamic geo-location selector.
#' This module generates a country selection dropdown and placeholders for
#' dynamic administrative levels (e.g., Province, Department) that are injected
#' by the server based on the selected country's configuration.
#'
#' @param id Character. The unique module ID used to namespace inputs and outputs.
#' @param country_config List. A configuration list for the default country. 
#'   (Note: While currently unused due to the global `ALL_CONFIGS` object, 
#'   it is kept for potential future scoping or testing).
#'
#' @return A named list containing two UI elements:
#' \describe{
#'   \item{sidebar}{A `shiny::tagList` containing the country selector and dynamic UI placeholders.}
#'   \item{main}{A `shiny::mainPanel` containing the Leaflet map output.}
#' }
#' 
#' @importFrom shiny NS tagList selectInput uiOutput mainPanel
#' @importFrom shinyjs useShinyjs
#' @importFrom leaflet leafletOutput
#' @export
geoLocationUI <- function(id, country_config) {
  ns <- shiny::NS(id)
  
  # 1. Build the UI components
  sidebar <- shiny::tagList(
    shinyjs::useShinyjs(), 
    
    shiny::selectInput(
      ns("country"), 
      label = "Select Country:", 
      # Removing the manual "Select Country" = "" option because our config now handles it
      choices = base::names(ALL_CONFIGS), 
      selected = "(Select Country)" 
    ),
    
    # Dynamic placeholder for levels (Province, Dept, etc.)
    # This stays empty until a country is selected
    shiny::uiOutput(ns("dynamic_levels_ui"))
  )
  
  main <- shiny::mainPanel(
    leaflet::leafletOutput(ns("map"), height = "600px", width = "100%")
  )
  
  base::return(base::list(sidebar = sidebar, main = main))
}