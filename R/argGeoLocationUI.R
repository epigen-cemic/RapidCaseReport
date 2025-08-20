        # =======================
        # UI Module
        # =======================


argGeoLocationUI <- function(id) {
  ns <- NS(id)
  
  sidebar <- tagList(
    selectInput(ns("country"), "Select Country:",
                choices = c("Argentina"), selected = "Argentina", multiple = FALSE) %>%
      tagAppendAttributes(disabled = "disabled"),
    selectInput(ns("Province"), "Select Province:", choices = c("No information available" = "")),
    selectInput(ns("Department"), "Select Department:", choices = c("No information available" = "")),
    selectInput(ns("Locality"), "Select Locality:", choices = c("No information available" = "")),
    textInput(ns("Fraction"), "Select an Area:", value = "No information available", width = "100%")
  )
  
  main <- mainPanel(
    leafletOutput(ns("map"), height = "600px", width = "100%")
  )
  
  # return as list
  list(
    sidebar = sidebar,
    main = main
  )
}
