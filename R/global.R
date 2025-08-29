

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
library(shiny.i18n)

# Load scripts

source("R/utils.R")
source("R/rumorForm.R")
source("R/argGeoLocation.R")
source("R/databaseInit.R")
source("R/databaseLoad.R")
source("R/icdAutocomplete.R")

i18n <- Translator$new(translation_csvs_path = "raw_data")
i18n$set_translation_language("english")