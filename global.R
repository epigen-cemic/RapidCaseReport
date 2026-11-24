# --- Framework & UI ---
library(shiny)
library(shinyjs)
library(leaflet)
library(DT)

# --- Data Processing & Paths ---
library(here)
library(jsonlite)
library(dplyr)
library(sf)
library(yaml)

# --- Database & Connectivity ---
library(DBI)
library(pool)
library(RSQLite)
library(uuid)

# --- Settings ---
config <- yaml::yaml.load_file("config.yaml")

# Load reusable configuration and UI helpers.
source(here::here("R", "shared", "config_helpers.R"))

app_version <- config$app$version %||% "2.0.0"
geo_config <- jsonlite::fromJSON(here::here("config.json"), simplifyVector = FALSE)

# Resolve the configured directory of country-specific geographic files.
data_dir <- here::here(config$data_dir %||% "raw_data")
if (!dir.exists(data_dir) && dir.exists(here::here("raw_data"))) {
  data_dir <- here::here("raw_data")
}

# Load module logic.
source(here::here("R", "utils.R"))
source(here::here("R", "report_geolocation.R"))
source(here::here("R", "report_processing.R"))
source(here::here("R", "report_database.R"))
source(here::here("R", "report_mapping.R"))
source(here::here("R", "report_form.R"))

# Initialize local app data store. This is an implementation detail and should
# not be exposed to end users as a downloadable database.
db_pool <- get_db_connection(config)

onStop(function() {
  if (exists("db_pool")) {
    pool::poolClose(db_pool)
    message("Database connection pool closed.")
  }
})
