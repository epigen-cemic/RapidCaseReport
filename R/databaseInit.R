library(DBI)
library(RSQLite)

initialize_database <- function(db_file = here("data", "your_database.dba")) {
  con <- dbConnect(SQLite(), db_file)

    dbExecute(con, "
    CREATE TABLE IF NOT EXISTS reports (
      id_code VARCHAR(36) PRIMARY KEY,
      consultation_date DATE,
      sex CHAR(1),
      birth_date DATE,
      province VARCHAR(100),
      department VARCHAR(100),
      locality VARCHAR(100),
      censal_fraction VARCHAR(7),
      symptom_onset_date DATE,
      symptom_description TEXT,
      suspected_diagnosis TEXT,
      icd10_code VARCHAR(10),
      confirmation_time DATETIME,
      email TEXT,
      institution TEXT
    )
  ")
    
    dbDisconnect(con)
    message('Database and table initialized with specified data types.')
  }
  
