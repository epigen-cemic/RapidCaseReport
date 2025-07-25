geoLocation <- function() {
  
  username <- "taxu" #activate user //
  selection_val <- reactiveVal(NULL)
  
  clear_lower_levels <- function(level, session) {
    if (level == "country") {
      updateSelectInput(session, "province", "Select Province:", choices = c("No information available" = ""))
      updateSelectInput(session, "department", "Select department:", choices = c("No information available" = ""))
      updateSelectInput(session, "locality", "Select locality:", choices = c("No information available" = ""))
    } else if (level == "province") {
      updateSelectInput(session, "department", "Select department:", choices = c("No information available" = ""))
      updateSelectInput(session, "locality", "Select locality:", choices = c("No information available" = ""))
    } else if (level == "department") {
      updateSelectInput(session, "locality", "Select locality:", choices = c("No information available" = ""))
    }
  }
  
  get_geoname_info <- function(url, name_xpath, use_bbox) {
    response <- GET(url)
    xml_data <- content(response, "text", encoding = "UTF-8")
    xml_parsed <- read_xml(xml_data)
    
    names <- xml_text(xml_find_all(xml_parsed, name_xpath))
    ids <- xml_text(xml_find_all(xml_parsed, "//geonameId"))
    urlName <- ifelse(use_bbox, "//bbox/", "//")
    wests <- xml_text(xml_find_all(xml_parsed, paste0(urlName, "west")))
    easts <- xml_text(xml_find_all(xml_parsed, paste0(urlName, "east")))
    norths <- xml_text(xml_find_all(xml_parsed, paste0(urlName, "north")))
    souths <- xml_text(xml_find_all(xml_parsed, paste0(urlName, "south")))
    
    if (length(names) == 0) return(NULL)
    
    info_list <- lapply(1:length(names), function(i) {
      list(
        name = names[i],
        geoname_id = ids[i],
        west = as.numeric(wests[i]),
        east = as.numeric(easts[i]),
        north = as.numeric(norths[i]),
        south = as.numeric(souths[i])
      )
    })
    
    names_only <- unlist(lapply(info_list, function(x) x$name))
    sorted_names <- mixedsort(names_only)
    sorted_index <- match(sorted_names, names_only)
    info_list <- info_list[sorted_index]
    
    return(info_list)
  }
  
  get_country_info <- function(username) {
    url <- paste0("http://api.geonames.org/countryInfo?username=", username)
    countries <- get_geoname_info(url, "//countryName", FALSE)
    lapply(countries, function(x) {
      x$country_name <- x$name
      x$name <- NULL
      x
    })
  }
  
  get_children_info <- function(geoname_id, username) {
    url <- paste0("http://api.geonames.org/children?geonameId=", geoname_id, "&style=full&username=", username)
    return(get_geoname_info(url, "//name", TRUE))
  }
  
  get_name_from_input <- function(input_id, info_list_func, input_value) {
    info_list <- info_list_func()
    if (!is.null(info_list) && length(info_list) > 0) {
      if (!is.null(input_value) && input_value != "") {
        return(get_name_from_id(info_list, input_value))
      } else {
        return(NULL)
      }
    } else {
      return("null")
    }
  }

  sidebar <- tagList(
    selectInput("country", "Select Country:", choices = NULL),
    selectInput("province", "Select Province:", choices = c("No information available" = "")),
    selectInput("department", "Select Department:", choices = c("No information available" = "")),
    selectInput("locality", "Select Locality:", choices = c("No information available" = ""))
  )
  main <- mainPanel(
    leafletOutput("map", height = "600px"),
    tags$style(HTML("
    #map {
      filter: brightness(0.8); 
    }
  "))
  )

    
  server <- function(input, output, session) {
    country_info_list <- get_country_info(username)
    province_info_list <- reactiveVal(NULL)
    department_info_list <- reactiveVal(NULL)
    locality_info_list <- reactiveVal(NULL)
    
    
    output$map <- renderLeaflet({
      leaflet() %>%
        addProviderTiles("CartoDB.Positron") %>%
        setView(lng = 0, lat = 0, zoom = 2)
    })
    
    
    req(country_info_list)
    country_names <- sapply(country_info_list, function(x) x$country_name)
    updateSelectInput(session, "country", 
                      choices = c("Select a country" = "", country_names), 
                      selected = "")
    
    
    observeEvent(input$country, {
      req(input$country)
      clear_lower_levels("country", session)
      
      selected_country_info <- country_info_list[sapply(country_info_list, function(x) x$country_name) == input$country][[1]]
      
      leafletProxy("map") %>%
        fitBounds(
          lng1 = selected_country_info$west,
          lat1 = selected_country_info$south,
          lng2 = selected_country_info$east,
          lat2 = selected_country_info$north
        )
      
      provinces <- tryCatch(
        get_children_info(selected_country_info$geoname_id, username),
        error = function(e) NULL
      )
      
      province_info_list(provinces)
      
      if (is.null(provinces)) {
        updateSelectInput(session, "province", choices = c("No information available" = ""))
      } else {
        province_names <- sapply(provinces, function(x) x$name)
        province_ids <- sapply(provinces, function(x) x$geoname_id)
        updateSelectInput(session, "province", choices = c("Select a province" = "", setNames(province_ids, province_names)))
      }
    })
    
    observeEvent(input$province, {
      req(input$province)
      clear_lower_levels("province", session)
      
      provinces <- province_info_list()
      selected_province_info <- provinces[sapply(provinces, function(x) x$geoname_id) == input$province][[1]]
      
      leafletProxy("map") %>%
        fitBounds(
          lng1 = selected_province_info$west,
          lat1 = selected_province_info$south,
          lng2 = selected_province_info$east,
          lat2 = selected_province_info$north
        )
      
      localities <- tryCatch(
        get_children_info(selected_province_info$geoname_id, username),
        error = function(e) NULL
      )
      
      department_info_list(localities)
      
      if (is.null(localities)) {
        updateSelectInput(session, "department", choices = c("No information available" = ""))
      } else {
        department_names <- sapply(localities, function(x) x$name)
        department_ids <- sapply(localities, function(x) x$geoname_id)
        updateSelectInput(session, "department", choices = c("Select a department" = "", setNames(department_ids, department_names)))
      }
    })
    
    observeEvent(input$department, {
      req(input$department)
      clear_lower_levels("department", session)
      
      localities <- department_info_list()
      selected_department_info <- localities[sapply(localities, function(x) x$geoname_id) == input$department][[1]]
      
      leafletProxy("map") %>%
        fitBounds(
          lng1 = selected_department_info$west,
          lat1 = selected_department_info$south,
          lng2 = selected_department_info$east,
          lat2 = selected_department_info$north
        )
      
      sublocalities <- tryCatch(
        get_children_info(selected_department_info$geoname_id, username),
        error = function(e) NULL
      )
      
      locality_info_list(sublocalities)
      
      if (is.null(sublocalities)) {
        updateSelectInput(session, "locality", choices = c("No information available" = ""))
      } else {
        locality_names <- sapply(sublocalities, function(x) x$name)
        locality_ids <- sapply(sublocalities, function(x) x$geoname_id)
        updateSelectInput(session, "locality", choices = c("Select a locality" = "", setNames(locality_ids, locality_names)))
      }
    })
    
    observeEvent(input$locality, {
      req(input$locality)
      sublocalities <- locality_info_list()
      selected_locality_info <- sublocalities[sapply(sublocalities, function(x) x$geoname_id) == input$locality][[1]]
      
      leafletProxy("map") %>%
        fitBounds(
          lng1 = selected_locality_info$west,
          lat1 = selected_locality_info$south,
          lng2 = selected_locality_info$east,
          lat2 = selected_locality_info$north
        )
    })
    
    
    observeEvent(input$save, {
      country_name <- input$country
      province_name <- get_name_from_input("province", province_info_list, input$province)
      department_name <- get_name_from_input("department", department_info_list, input$department)
      locality_name <- get_name_from_input("locality", locality_info_list, input$locality)
      
      validate(
        need(country_name, "Country is required or unknown"),
        need(province_name, "Province is required or unknown."),
        need(department_name, "Department is required or unknown."),
        need(locality_name, "Locality is required or unknown.")
      )
      
      selection_val(list(
        country = country_name,
        province = province_name,
        department = department_name,
        locality = locality_name
      ))
    })
  }
  
  return(list(sidebar = sidebar, main = main, server = server, selection = selection_val))
}
