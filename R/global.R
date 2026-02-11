# ==============================================================================
# GLOBAL CONFIGURATION - Rumor Report Form v1.2
# ==============================================================================

# 1. Load Libraries
library(shiny)
library(dplyr)
library(uuid)
library(httr)
library(jsonlite)
library(leaflet)
library(sf)
library(here)
library(arrow)
library(shinyjs)


# 2. Source Module Scripts
source("R/utils.R")
source("R/rumorForm.R")
source("R/databaseInit.R")
source("R/databaseLoad.R")
source("R/geoLocationUI.R")
source("R/geoLocationServer.R")

# 3. Load Master Configuration
config_path <- here::here("www/config.json")

ALL_CONFIGS <- tryCatch({
  jsonlite::fromJSON(config_path)
}, error = function(e) {
  stop(paste("Failed to load config.json. Check if the file is empty or has syntax errors. Error:", e$message))
})


# 4. Environment Variables Health Check
admin_email <- Sys.getenv("ADMIN_EMAIL")
admin_password <- Sys.getenv("ADMIN_PASSWORD")
db_path <- Sys.getenv("DB_PATH")

