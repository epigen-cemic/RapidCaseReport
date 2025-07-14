geoLocation <- function() {
  
  library(shiny)
  library(leaflet)
  library(geoAr)
  library(dplyr)
  library(sf)
  
  # Cargar geometrías
  province_sf <- get_geo("ARGENTINA", level = "provincia")
  department_sf <- get_geo("ARGENTINA", level = "departamento")
  
  #data("geo_metadata", package = "geoAr")
                 # ///////
  # Modificar estas lineas una vez obtenido acceso a los datos del censo
  
  # Cargar los datos censales de 2010 (supuesto CSV con columnas: coddepto_censo, poblacion_total, poblacion_hombres, poblacion_mujeres, etc.)
  #censo_2010 <- read.csv("ruta/a/tu/archivo_censo2010.csv")    <----- De tener los datos en un archivo
  
  #url_censo <- "https://example.com/archivo_censo2010.csv"  # Reemplaza con la URL real
  #censo_2010 <- read.csv(url_censo)          <------- De leer los datos desde la web
  
  # Unir los datos censales con las geometrías de departamentos
  #epartamentos_sf <- left_join(department_sf, censo_2010, by = c("coddepto_censo" = "coddepto_censo"))
                # ////////

  # Vector de provincias
  province_names <- c(
    "Ciudad de Buenos Aires" = "02", "Buenos Aires" = "06",
    "Catamarca" = "10", "Córdoba" = "14", "Corrientes" = "18",
    "Chaco" = "22", "Chubut" = "26", "Entre Ríos" = "30",
    "Formosa" = "34", "Jujuy" = "38", "La Pampa" = "42",
    "La Rioja" = "46", "Mendoza" = "50", "Misiones" = "54",
    "Neuquén" = "58", "Río Negro" = "62", "Salta" = "66",
    "San Juan" = "70", "San Luis" = "74", "Santa Cruz" = "78",
    "Santa Fe" = "82", "Santiago del Estero" = "86",
    "Tierra del Fuego" = "90", "Tucumán" = "94"
  )
  
  # Vector a lista 
  province_names_list <- as.list(province_names)
  
  
  sidebar <- list(
    selectInput("province_id", "Residence Province:",
                choices = c("Search Province..." = "", province_names)),
    selectInput("department_id", "Residence Locality:",
                choices = c("Search Locality..." = ""))
  )
  

  main <- mainPanel(
    leafletOutput("mapa", height = "400px"),
    verbatimTextOutput("info_censal")
  )
    
  
  server <- function(input, output, session) {
    

    observe({
      req(input$province_id)
      department_province <- department_sf %>%
        filter(codprov_censo == input$province_id)  
      
      updateSelectInput(session, "department_id", 
                        choices = c("Search Locality..." = "", 
                                    setNames(department_province$coddepto_censo, department_province$coddepto_censo)),
                        selected = NULL)
    })
    
    output$mapa <- renderLeaflet({
      base_map <- leaflet() %>%
        addProviderTiles("CartoDB.PositronNoLabels") %>%
        addPolygons(data = province_sf,
                    color = "gray", weight = 1,
                    fillColor = "#acaeb0", fillOpacity = 0.9) %>%
        setView(lng = -64, lat = -35, zoom = 4) %>%
        setMaxBounds(lng1 = -75, lat1 = -56, lng2 = -53, lat2 = -21)
      
      if (input$province_id != "") {
        selected_province <- province_sf %>% filter(codprov_censo == input$province_id)
        base_map <- base_map %>%
          addPolygons(data = selected_province,
                      color = "#73b2e1", weight = 2,
                      fillColor = "lightblue", fillOpacity = 0.8)
      }
      
      if (input$department_id != "") {
        selected_department <- department_sf %>%
          filter(coddepto_censo == input$department_id,
                 codprov_censo == input$province_id)
        base_map <- base_map %>%
          addPolygons(data = selected_department,
                      color = "darkblue", weight = 2,
                      fillColor = "lightgreen", fillOpacity = 0.8)
      }
      
      base_map
    })
    
    output$info_censal <- renderText({
      req(session$userData$show_census_info())
      req(input$department_id)
      
      department_info <- department_sf %>%
        filter(coddepto_censo == input$department_id)
      
      paste("Census information:",
            input$department_id, "\n",
            "Total population: ", department_info$poblacion_total, "\n",
            "Male population: ", department_info$poblacion_hombres, "\n",
            "Female population: ", department_info$poblacion_mujeres, "\n",
            "Population 0-14 years: ", department_info$poblacion_0_14, "\n",
            "Population 15-64 years: ", department_info$poblacion_15_64, "\n",
            "Population 65+ years: ", department_info$poblacion_65_plus)
    })
  }
  
  return(list(sidebar = sidebar, main = main, server = server))

}