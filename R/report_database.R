#' Open the local reporting data store
#'
#' Resolve the configured SQLite file, create its parent directory if needed, initialize the
#' reports schema, and return a database pool.
#'
#' @details Opening this pool also initializes or changes the local reports schema; do not treat it
#'   as a read-only connection test.
#'
#' @param app_config Parsed application configuration, including local database settings.
#' @return An initialized connection pool.
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

  # Initialization can create or alter local tables; it is not a read-only check.
  init_db_tables(pool, table = db_cfg$table %||% "reports")
  message("Connected to local app data store at: ", db_path)
  pool
}

#' Initialize or migrate the local reports table
#'
#' Create the reports table when absent; otherwise add missing columns through the existing
#' migration helper.
#'
#' @param pool Database pool used by the reporting application.
#' @param table Name of the destination reports table.
#' @return The result of schema initialization (invisible when applicable).
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

#' Add missing columns to legacy report tables
#'
#' Alter an existing reports table to include current report columns and copy confirmation_time
#' into missing submitted_at values.
#'
#' @details On legacy tables, this operation performs ALTER TABLE and UPDATE statements. Existing
#'   report rows are not deleted by this function.
#'
#' @param pool Database pool used by the reporting application.
#' @param table Name of the destination reports table.
#' @return Invisible TRUE on completion.
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

#' Append one report to the local data store
#'
#' Align a report row to the existing destination columns and append it; on failure, log a message
#' and return FALSE.
#'
#' @param new_entry Single-row data frame containing a report for insertion.
#' @param pool Database pool used by the reporting application.
#' @param table Name of the destination reports table.
#' @return TRUE when append succeeds, otherwise FALSE.
#' @export
insert_to_db <- function(new_entry, pool, table = config$database$table %||% "reports") {
  tryCatch({
    fields <- DBI::dbListFields(pool, table)
    missing <- setdiff(fields, names(new_entry))
    for (col in missing) {
      new_entry[[col]] <- NA_character_
    }
    # Use destination-column order and avoid adding fields absent from the table.
    new_entry <- new_entry[, intersect(fields, names(new_entry)), drop = FALSE]
    DBI::dbWriteTable(pool, table, new_entry, append = TRUE)
    message("Data successfully inserted.")
    TRUE
  }, error = function(e) {
    message("Error inserting data: ", e$message)
    FALSE
  })
}
