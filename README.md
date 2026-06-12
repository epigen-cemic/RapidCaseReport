# RapidCaseReport v2.0

RapidCaseReport is an R/Shiny application for rapid reporting of suspected health events. It collects individual, location, symptom, diagnosis, and professional information through a guided form and stores confirmed submissions in a local app data store.

Version 2.0 aligns the app more closely with the current RAP tool family, including API-POP v2.0, CUSUM RAP, Geospatial RAP, and the Digital Dashboard.

## Main changes in v2.0

- Updated application version and documentation to v2.0.
- Removed the previous user-facing database-history download workflow.
- Kept only the current-session CSV download for records submitted during the active session.
- Added timestamped CSV filenames.
- Added an empty CSV output instead of failing when no session records exist.
- Added shared helper functions under `R/shared/`.
- Updated geographic helpers to use config-driven `level1`, `level2`, and `level3` mappings.
- Added `name_col` support for spatial layer labels.
- Added CRS safety for Leaflet maps through `ensure_leaflet_crs()`.
- Improved map/table containment so the map no longer overflows over the record table.
- Updated the theme to better match the newer RAP tools.
- Removed `.Renviron` as a required project file.
- Simplified local SQLite persistence as an internal app detail.

## Project structure

```text
RapidCaseReport/
├── app.R
├── global.R
├── config.json
├── config.yaml
├── R/
│   ├── report_database.R
│   ├── report_form.R
│   ├── report_geolocation.R
│   ├── report_mapping.R
│   ├── report_processing.R
│   ├── utils.R
│   └── shared/
│       └── config_helpers.R
├── data/
├── data_prep/
│   ├── merge_layers.R
│   ├── Preparing Geographic Data.md
│   └── prepare_rapid_case_report_database.R
├── raw_data/
│   ├── Argentina.gpkg
│   ├── ICD10_codes.csv
│   └── localities.parquet
└── www/
    ├── AnalysisforAction_white.png
    └── config.css
```

## Requirements

Recommended R packages:

```r
install.packages(c(
  "shiny",
  "shinyjs",
  "leaflet",
  "DT",
  "here",
  "jsonlite",
  "dplyr",
  "sf",
  "yaml",
  "DBI",
  "pool",
  "RSQLite",
  "uuid"
))
```

## Run locally

```r
setwd("path/to/RapidCaseReport")
shiny::runApp()
```

Or from a terminal:

```bash
Rscript --vanilla -e "shiny::runApp('.', host = '127.0.0.1', port = 3838)"
```

## Configuration

### `config.yaml`

`config.yaml` controls app-level paths and version metadata.

```yaml
app:
  version: "2.0.0"

data_dir: "raw_data"

database:
  type: "sqlite"
  path: "data/report_database.db"
  table: "reports"
```

The local SQLite file is an internal persistence layer. It should not be presented as a user-facing database download.

### `config.json`

`config.json` controls countries, geographic levels, spatial layers, and labels.

Each country should define:

- `name`
- `file_name`
- `levels`
- `mapping`

Each mapped level should include:

- `db_column`
- `layer_name`
- `spatial_id`
- `name_col`
- `ui_label`
- `parent_col` for child levels

## Preparing geographic data

Use `data_prep/merge_layers.R` to create country `.gpkg` files with the required layers.

Each configured spatial layer should contain the configured `spatial_id`, `name_col`, and parent columns required by `config.json`.

## Preparing/resetting local app data

For local testing, run:

```r
source("data_prep/prepare_rapid_case_report_database.R")
```

This creates an empty `reports` table with the current v2.0 schema.

Do not commit local app data containing test or real reports.

## End-user workflow

1. Enter general case information.
2. Select the case location through the configured geography dropdowns and map.
3. Enter symptom and suspected diagnosis information.
4. Enter professional information.
5. Click **Submit Report**.
6. Review the confirmation dialog carefully.
7. Confirm to save the record.
8. Download the current session records as CSV if needed.

Confirmed records are saved immediately and cannot be edited from this form.

## Release checklist

Before publishing v2.0:

- Confirm the app starts locally.
- Confirm `R/shared/config_helpers.R` exists.
- Confirm `data_dir` points to `raw_data` or another folder containing the configured `.gpkg` file.
- Confirm the database-history download button is gone.
- Confirm map selections work.
- Confirm the map does not overflow over the records table.
- Confirm valid form submission works.
- Confirm invalid/missing required fields show validation messages.
- Confirm current-session CSV download works, including with zero rows.
- Confirm `.Renviron`, `.RData`, `.Rhistory`, `.Rproj.user/`, `.git/`, and local test data are not included in release zips.

## Project

**Project:** PPT-UK – Argentina Work Package WS5
**Institution / Delivery Partner:** CEMIC
