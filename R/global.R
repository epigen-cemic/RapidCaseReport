library(shiny)
library(dplyr)
library(uuid)
library(httr)
library(jsonlite)
library(Rcpp)
library(leaflet)
library(sf)
library(xml2)
library(gtools)
library(here)
library(arrow)
library(shinyjs)

# Load scripts

source("R/utils.R")
source("R/rumorForm.R")
source("R/argGeoLocation.R")
source("R/databaseInit.R")
source("R/databaseLoad.R")


# The following information is in a .Renviron to keep safe and invisible to users
# for servers this is done as an enviroment variable.
admin_email <- Sys.getenv("ADMIN_EMAIL")
admin_password <- Sys.getenv("ADMIN_PASSWORD")
db_path <- Sys.getenv("DB_PATH")

