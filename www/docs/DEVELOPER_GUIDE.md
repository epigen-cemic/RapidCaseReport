# RapidCaseReport: Developer guide

**Audience:** developers, reviewers, and maintainers  
**Software release line:** RapidCaseReport v2.x; documentation reflects current application source  
**Documentation revision:** 23 November 2026  
**Scope:** implemented behaviour, code responsibilities, operational assumptions and known limitations

## 1. Purpose and supported behaviour

RapidCaseReport is an R/Shiny reporting form for suspected health events. It collects consultation and birth dates, sex, hierarchical geographic location, symptom onset and description, suspected diagnosis, and reporting-professional information. Users identify the finest mapped geographic area on a Leaflet map, review a confirmation dialog, submit the case to a local SQLite data store, and download a CSV containing **only records saved in the current Shiny session**.

This source does **not** offer administrator login, download-by-email history, database-wide download, arbitrary external database connectivity, automatic synchronization, or an edit/delete workflow for previously submitted reports.

## 2. Repository orientation

| Path | Responsibility |
|---|---|
| `app.R` | Main Shiny UI/server initialization. |
| `global.R` | Load dependencies, configuration, modules, geographic directory and database pool. |
| `R/report_form.R` | Reporting UI, input validation orchestration, confirmation, append and session CSV. |
| `R/report_geolocation.R` | Geographic selectors, Leaflet map and reactive location state. |
| `R/report_mapping.R` | Geographic rendering and map highlighting helpers. |
| `R/report_processing.R` | Form checks, geographic data access and report serialization. |
| `R/report_database.R` | SQLite pool, schema initialization/migration and insertion. |
| `R/utils.R` | UUID generation, zoom calculations, location-state and spatial CRS helpers. |
| `R/shared/config_helpers.R` | Country mapping, labels, CSV writing and DT presentation. |
| `config.yaml` | App version, geographic data directory, database file and table. |
| `config.json` | Geographic levels, layers, IDs, names, parent columns and labels. |
| `www/config.css` | Visual identity, form layout and controls. |
| `www/docs/` | Three audience guides and the reporting data dictionary. |
| `R/renv.lock`, `R/renv/` | Dependency lock/activation assets as packaged; review actual project-root activation. |

By default the application expects a GeoPackage at `raw_data/Argentina.gpkg`. Institutional distributions must provide appropriate licensed reference data.

## 3. Startup, lifecycle, and data persistence

1. `app.R` sources `global.R` and declares `caseReportUI("form")`.
2. `global.R` reads `config.yaml` and `config.json`, resolves `data_dir`, and sources the feature modules.
3. `get_db_connection(config)` creates the local parent directory if needed, opens a SQLite pool, and calls `init_db_tables()`.
4. `init_db_tables()` creates `reports` when missing or invokes `ensure_report_columns()` for an existing table. On older tables it may issue `ALTER TABLE` and `UPDATE` statements.
5. The Shiny server starts `geoLocationServer()` and passes its reactive location to `caseReportServer()`.
6. `onStop()` closes the database pool when the application terminates.

Starting the app can create or modify a local database; it is **not** a read-only connection test. Keep real data outside source control and protect file backups and database permissions.

Dependencies used by the source include `shiny`, `shinyjs`, `leaflet`, `DT`, `here`, `jsonlite`, `dplyr`, `sf`, `yaml`, `DBI`, `pool`, `RSQLite`, and `uuid`. The supplied lockfile is under `R/renv.lock` rather than the usual project root; review the `renv` restoration strategy instead of assuming it activates automatically from the repository root.

## 4. Form and geographic workflow

### 4.1 Form entry

`caseReportUI()` has a left sidebar for general information, location, symptoms, suspected diagnosis and professional information. The right panel contains the map and a *Current session records* table. The action button is **Submit Report**.

`caseReportServer()` invokes `validate_form_inputs()` before showing *Confirm Submission*. When confirmed, `format_new_entry()` creates a UUID/timestamp record and `insert_to_db()` appends it to the SQLite table. A successful append adds the row to the in-session reactive table. The patient's date, sex, symptom and diagnosis fields are reset; geographic and professional fields remain as they were.

The current validation requires sex, email, institution, symptom description, suspected diagnosis, country and a finest-level map selection, and it rejects birth dates after consultation dates. **It does not currently enforce all symptom-onset chronology checks** described in previous manuals. Future-date picker limits are UI constraints rather than comprehensive persisted-data validation.

### 4.2 Geographic selection

`geoLocationServer()` loads the country hierarchy from `config.json`, populates level 1 and level 2 dropdowns, draws level 3 polygons, and sets the selected finest-area identifier when a shape is clicked. Changes to parent selections clear dependent state. `plot_on_map()` and `plot_finest_areas()` in `R/report_mapping.R` handle Leaflet geometry styling and highlights; `get_info_about()` in `R/report_processing.R` queries the configured GeoPackage.

The UI is built for up to three configured geographic levels; extending to additional tiers requires code changes. The initial Leaflet view is centred on Argentina. The GeoPackage code/parent mapping must be verified for every added country.

## 5. Internal function reference

| Function or group | File | Responsibility |
|---|---|---|
| `caseReportUI()` / `caseReportServer()` | `R/report_form.R` | Form UI, review, confirmation, save and session preview/export. |
| `geoLocationUI()` / `geoLocationServer()` | `R/report_geolocation.R` | Dropdowns, map, location reactive state. |
| `validate_form_inputs()` | `R/report_processing.R` | Required-field and birth/consultation checks. |
| `format_new_entry()` | `R/report_processing.R` | Assemble a one-row report and timestamps. |
| `get_info_about()` | `R/report_processing.R` | Load spatial data through a dynamic SQL query. |
| `get_db_connection()` / `init_db_tables()` | `R/report_database.R` | Open local database and initialize schema. |
| `ensure_report_columns()` | `R/report_database.R` | Add legacy columns and populate missing submission timestamps. |
| `insert_to_db()` | `R/report_database.R` | Append one record, returning success or failure. |
| `plot_on_map()` / `plot_finest_areas()` | `R/report_mapping.R` | Draw and highlight geographic shapes. |
| `update_location_state()` / `ensure_leaflet_crs()` | `R/utils.R` | Update reactive geographic state / prepare CRS. |
| `get_mapping_keys()` / `get_level_key_by_db_column()` | `R/shared/config_helpers.R` | Resolve generic geographic levels and configured database names. |
| `timestamped_filename()` / `write_csv_utf8()` / `app_datatable()` | `R/shared/config_helpers.R` | Session CSV names, writing and table rendering. |

See the Roxygen2 blocks in the source for each named function's signature, return contract and side effects. Do not treat internal module helpers as a stable public API.

## 6. Stored record and export

The table name defaults to `reports`. A newly initialized table has `id_code` as text primary key and these fields: `consultation_date`, `sex`, `birth_date`, `country`, `level1`, `level2`, `level3`, `symptom_onset_date`, `symptom_description`, `suspected_diagnosis`, `confirmation_time`, `submitted_at`, `email` and `institution`.

The current geographic values mix human-readable selected level 1/2 names with a finest-area code at level 3. Canonical geographic-code columns are not part of the current stored record format; adding them requires a separately tested schema change. The **Download Current Session CSV** action writes the reactive `form_records` data, not historical database contents. A new browser session cannot retrieve an earlier session's records through this UI.

### Data quality: symptom and diagnosis terminology

The symptom_description and suspected_diagnosis fields contain free-text values. Users may record the same clinical concept using different spellings, abbreviations or levels of detail. Current submission does not enforce a controlled clinical vocabulary.

Institutions using these reports for API-POP analysis should consider validation rules, locally approved terminology or a documented cleaning and coding procedure. Preserve original entries when needed for audit and clinical interpretation.

### Deployment and access control

The local SQLite data store is a reference implementation, not a complete security model. Institutions are responsible for authentication, user permissions, credential management, data governance, encrypted transport where applicable, secure exports, retention and backups. The application source does not include a role-based user-account system.

Single-device local use is directly represented by the current source. A centrally hosted Shiny deployment requires an institutional assessment of storage persistence, access controls and concurrent use. A managed external database may be appropriate for multiple reporters, but using one requires separate connector implementation, permissions review and regression testing.

### Cross-document references

See README.md for startup and repository orientation, www/docs/Data_Dictionary_RapidCaseReport.md for the stored fields, and www/docs/RapidCaseReport_Local_Data_Store.md for local persistence. The institutional setup guide explains geographic configuration. These are repository-relative paths, not assumed public web links.

## 7. Source versioning and publication metadata

| Source | Current value / interpretation |
|---|---|
| `config.yaml` | `app.version: "2.0.0"` controls the visible version badge. |
| `app.R` | Header mentions v2.0. |
| `CITATION.cff` | Declares software `version: 2.0.1`, date `2026-06-12`. |
| `.Rproj` | Filename contains `v1-5`; this is historical naming, not evidence of a complete release history. |
| `CITATION.cff` `cff-version` | Set to `1.2.0`, the Citation File Format schema version; separate from software version `2.0.1`. |

The source package contains no verified, complete version-by-version change log. Do not invent historical versions. For each future release, reconcile badge, citation metadata, README, documentation, package provenance, change log and testing evidence in one release checklist.

## 8. Maintenance risks and tests

**Known concerns requiring separate functional work:**

- The confirmation HTML includes raw form values and requires HTML escaping; dialog values are not frozen into an immutable snapshot before final insertion.
- The spatial query in `get_info_about()` interpolates values into SQL rather than binding them; validate trusted inputs and harden queries before untrusted sources are allowed.
- Symptom-onset chronology and other input edge cases are not fully checked.
- `ensure_leaflet_crs()` assumes EPSG:4326 when a source CRS is missing; a missing CRS is not proof of that coordinate system.
- The code does not implement per-user authorisation or a history-download policy; deployment controls are the institution's responsibility.

**Recommended release tests:** parse and launch in a clean R session; create a temporary empty SQLite database; submit a synthetic report; inspect the stored row; submit a duplicate-ID negative test; verify errors do not enter the preview; test all geographic cascades and map clicks; test date boundaries; test special HTML characters in fields; download session CSV and verify row count; restart the app and confirm the UI does not expose old database rows as session rows. Test schema migration only against a backup.

## 9. Developer handover rules

Keep clinical validation in `report_processing.R`, persistence in `report_database.R`, map logic in `report_geolocation.R`/`report_mapping.R`, and UI coordination in `report_form.R`. Make changes coherently, with tests for each cross-module contract. If a new field is added, update the form, validation, record serializer, SQLite schema, session preview, export dictionary, administrator guide and user guide together. Avoid embedding change-history remarks in code comments; the version history belongs in release notes.
