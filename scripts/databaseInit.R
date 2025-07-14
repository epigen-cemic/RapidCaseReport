library(DBI)
library(RSQLite)

# Función para crear la tabla en SQLite
initialize_database <- function(db_file = "data/Dummy_database.dba") {
  con <- dbConnect(SQLite(), db_file)

    # Crear tabla con los tipos de datos especificados
    dbExecute(con, "
    CREATE TABLE IF NOT EXISTS reports (
      id_code VARCHAR(36) PRIMARY KEY,
      consultation_date DATE,
      sex CHAR(1),
      birth_date DATE,
      residence_country VARCHAR(100),
      residence_province VARCHAR(100),
      residence_locality VARCHAR(100),
      symptom_onset_date DATE,
      symptom_description TEXT,
      hpo_codes VARCHAR(255),
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
  
