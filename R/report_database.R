#' Initialize local database connection pool
#'
#' @description Creates a local SQLite data store for submitted reports. The
#' database is an internal persistence layer, not a user-facing download source.
#'
#' @param app_config List loaded from config.yaml.
#' @return A pool object.
#' @export
get_db_connection <- function(app_config = config) {
  db_cfg <- app_config$database %||% list()
  db_path <- db_cfg$path %||% "data/report_database.db"
  db_path <- here::here(db_path)

  db_dir <- dirname(db_path)
  if (!dir.exists(db_dir)) {
    dir.create(db_dir, recursive = TRUE, showWarnings = FALSE)
  }

  pool <- pool::dbPool(
    drv = RSQLite::SQLite(),
    dbname = db_path
  )

  init_db_tables(pool, table = db_cfg$table %||% "reports")
  message("Connected to local app data store at: ", db_path)
  pool
}

#' Initialize database tables
#'
#' @description Creates or migrates the standardized reports table using generic
#' geographic levels.
#' @param pool The active database pool.
#' @param table Character table name. Defaults to reports.
#' @export
init_db_tables <- function(pool, table = "reports") {
  if (!DBI::dbExistsTable(pool, table)) {
    DBI::dbExecute(pool, sprintf(
      "CREATE TABLE %s (
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
      )",
      DBI::dbQuoteIdentifier(pool, table)
    ))
    message("Database initialized with generic geographic levels.")
  } else {
    ensure_report_columns(pool, table = table)
  }
}

#' Add missing report columns to older local databases
#' @param pool The active database pool.
#' @param table Character table name. Defaults to reports.
#' @return Invisibly TRUE.
#' @keywords internal
ensure_report_columns <- function(pool, table = "reports") {
  existing <- DBI::dbListFields(pool, table)
  required <- c(
    id_code = "TEXT",
    consultation_date = "TEXT",
    sex = "TEXT",
    birth_date = "TEXT",
    country = "TEXT",
    level1 = "TEXT",
    level2 = "TEXT",
    level3 = "TEXT",
    symptom_onset_date = "TEXT",
    symptom_description = "TEXT",
    suspected_diagnosis = "TEXT",
    confirmation_time = "TEXT",
    submitted_at = "TEXT",
    email = "TEXT",
    institution = "TEXT"
  )

  for (col in setdiff(names(required), existing)) {
    DBI::dbExecute(
      pool,
      sprintf(
        "ALTER TABLE %s ADD COLUMN %s %s",
        DBI::dbQuoteIdentifier(pool, table),
        DBI::dbQuoteIdentifier(pool, col),
        required[[col]]
      )
    )
  }

  if ("submitted_at" %in% DBI::dbListFields(pool, table) && "confirmation_time" %in% existing) {
    DBI::dbExecute(
      pool,
      sprintf(
        "UPDATE %s SET %s = %s WHERE %s IS NULL AND %s IS NOT NULL",
        DBI::dbQuoteIdentifier(pool, table),
        DBI::dbQuoteIdentifier(pool, "submitted_at"),
        DBI::dbQuoteIdentifier(pool, "confirmation_time"),
        DBI::dbQuoteIdentifier(pool, "submitted_at"),
        DBI::dbQuoteIdentifier(pool, "confirmation_time")
      )
    )
  }

  invisible(TRUE)
}

#' Insert New Entry
#' @param new_entry Data frame with one row.
#' @param pool The active database pool.
#' @param table Character table name. Defaults to reports.
#' @export
insert_to_db <- function(new_entry, pool, table = config$database$table %||% "reports") {
  tryCatch({
    fields <- DBI::dbListFields(pool, table)
    missing <- setdiff(fields, names(new_entry))
    for (col in missing) {
      new_entry[[col]] <- NA_character_
    }
    new_entry <- new_entry[, intersect(fields, names(new_entry)), drop = FALSE]
    DBI::dbWriteTable(pool, table, new_entry, append = TRUE)
    message("Data successfully inserted.")
    TRUE
  }, error = function(e) {
    message("Error inserting data: ", e$message)
    FALSE
  })
}
