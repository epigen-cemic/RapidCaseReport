

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
source("R/argGeoLocation.R")
source("R/databaseInit.R")
source("R/databaseLoad.R")

argGeoLocation <- argGeoLocation()