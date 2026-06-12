# Prepare/reset RapidCaseReport local app data store
#
# Run from the project root:
# source("data_prep/prepare_rapid_case_report_database.R")

required_packages <- c("DBI", "RSQLite", "yaml", "here")
missing <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing) > 0) {
  stop("Missing packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

cfg <- yaml::yaml.load_file("config.yaml")
db_path <- here::here(cfg$database$path %||% "data/report_database.db")

dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

if (file.exists(db_path)) {
  file.remove(db_path)
}

con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
on.exit(DBI::dbDisconnect(con), add = TRUE)

DBI::dbExecute(con, "
CREATE TABLE reports (
  id_code TEXT PRIMARY KEY,
  consultation_date TEXT,
  sex TEXT,
  birth_date TEXT,
  country TEXT,
  level1 TEXT,
  level2 TEXT,
  level3 TEXT,
  symptom_onset_date TEXT,
  symptom_description TEXT,
  suspected_diagnosis TEXT,
  confirmation_time TEXT,
  submitted_at TEXT,
  email TEXT,
  institution TEXT
)
")

message("Created empty RapidCaseReport local app data store: ", db_path)
print(DBI::dbGetQuery(con, "PRAGMA table_info(reports)"))
