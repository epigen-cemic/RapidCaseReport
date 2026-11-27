# RapidCaseReport

RapidCaseReport is an R/Shiny form for recording suspected health events with geographic selection on a Leaflet map. Confirmed reports are saved in a local SQLite data store. The user interface displays and exports only reports saved during the current Shiny session.


## Quick start

1. Review `config.yaml`: `data_dir` (default `raw_data`), `database.path` (default `data/report_database.db`) and table name.
2. Ensure `raw_data/Argentina.gpkg` or your configured country data exists and matches `config.json`.
3. Install packages imported by `global.R`; review `R/renv.lock` and project environment setup before attempting a reproducible restore.
4. From the project root, run `shiny::runApp(".")` using a **test database first**. Startup may initialize or alter the SQLite table.
5. Select a country and areas, click a final area on the map, complete the form, confirm a synthetic report, and verify current-session CSV download.

## Main modules

`app.R` → `global.R` → `R/report_form.R`, `R/report_geolocation.R`, `R/report_processing.R`, `R/report_database.R` and `R/report_mapping.R`. Shared geographic labels and UI utilities are in `R/shared/config_helpers.R`; `R/utils.R` holds general map/ID helpers. Styling is under `www/config.css`.

## Documentation by audience

- [Documentation index](www/docs/DOCUMENTATION_INDEX.md)
- [End-User Guide](www/docs/USER_GUIDE.md) (`www/docs/RapidCaseReport_User-Guide.docx`)
- [Institutional Setup Guide](www/docs/INSTITUTIONAL_SETUP_GUIDE.md)
- [Developer Guide](www/docs/DEVELOPER_GUIDE.md)
- [Reports data dictionary](www/docs/Data_Dictionary_RapidCaseReport.md)
- [Local data store reference](www/docs/RapidCaseReport_Local_Data_Store.md)

## Current limitations

This source does not support administrator-password access, email-based historical exports, external database adapters or report editing. Data validation is not comprehensive for symptom-onset chronology; confirmation HTML and geographic query interpolation require security hardening before an unrestricted deployment. A reproducible automated application test suite should be established before institutional deployment.

## Operational data handling

The SQLite file is local to the Shiny host; it is not a download offered to end users. Configure appropriate authorization, encrypted transport, filesystem protection, backup/restore and data retention before using real case records.
