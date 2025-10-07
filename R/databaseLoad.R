library(RSQLite)

insert_to_db <- function(new_entry) {
  con <- dbConnect(SQLite(), dbname = db_path)
  on.exit(dbDisconnect(con), add = TRUE)
  dbBegin(con)
  
  tryCatch({
    if (!dbExistsTable(con, "reports")) {
      dbCreateTable(con, "reports", new_entry)
    }
    dbWriteTable(con, "reports", new_entry, append = TRUE, row.names = FALSE)
    dbCommit(con)
    cat("Data successfully inserted into the database.\n")
    
  }, error = function(e) {
    dbRollback(con)
    cat("Error inserting data: ", e$message, "\n")
  })
}

download_email <- function(email, output_file) {
  con <- dbConnect(SQLite(), dbname = db_path)
  on.exit(dbDisconnect(con), add = TRUE)
  
  query <- sprintf("SELECT * FROM reports WHERE email = '%s'", email)
  data <- dbGetQuery(con, query)
  
  if (nrow(data) == 0) {
    stop("No entries found for this email.")
  }
  write.csv(data, output_file, row.names = FALSE)
}



download_admin <- function(output_file) {
  db_path <- Sys.getenv("DB_PATH")
  
  if (!file.exists(db_path)) {
    stop("Database file does not exist at ", db_path)
  }
  
  # Copy the full database file
  # This could take a long time if the database get to large. NOT Recomended
  file.copy(db_path, output_file, overwrite = TRUE)
}
