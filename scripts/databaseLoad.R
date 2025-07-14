library(RSQLite)

insert_to_db <- function(new_entry) {
  con <- dbConnect(SQLite(), "data/Dummy_database.dba")
  

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
  
  dbDisconnect(con)
}