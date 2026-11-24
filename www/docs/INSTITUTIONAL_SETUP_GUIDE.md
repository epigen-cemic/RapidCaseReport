# RapidCaseReport: Institutional setup and country configuration

**Audience:** institutional administrators, technical deployment staff and data custodians  
**Software release line:** RapidCaseReport v2.x  
**Documentation revision:** 23 November 2026

## 1. Deployment model

The current source uses a local SQLite database file and configured GeoPackage boundaries. It does not provide an external-database selection screen, an administrator account, or role-based access control. Confirmed reports are written to the SQLite file; the application's download button exports only rows from the active user session. The organisation hosting the application is responsible for authentication, secure transport, storage permissions, backups, data governance and retention.

A Shiny app's local data directory belongs to the **host running Shiny**, not necessarily the user's computer. On ephemeral hosts this directory may be reset; do not use ephemeral storage for production reports without independently managed persistence.

### Practical deployment options

Single-user local use: one authorised worker runs the app on a controlled device, with the SQLite file stored in a protected local directory. Define device security, backups and retention before collecting case information.

Institution-hosted access: staff use an organisation-managed Shiny server. The institution must assess user authentication, network transport, server storage persistence and concurrent database writes. The current code does not supply these security controls automatically.

Multi-user central reporting: a managed database may be preferable where several staff report concurrently. The current RapidCaseReport source does not implement a general external database connector; this is an integration project requiring an approved adapter, schema mapping, permissions testing and governance review.

### Access control and information governance

RapidCaseReport may hold sensitive health and professional information. The default SQLite setup is not a production security model. The deploying institution is responsible for access controls, authentication, credential handling, retention, backups, recovery procedures and applicable information-governance requirements.

## 2. Deployment preparation

1. Create a protected institutional copy of the repository. Do not commit clinical reports or credentials.
2. Confirm that the host has R and the packages used in `global.R` (`shiny`, `shinyjs`, `leaflet`, `DT`, `here`, `jsonlite`, `dplyr`, `sf`, `yaml`, `DBI`, `pool`, `RSQLite`, `uuid`).
3. Review the packaged `R/renv.lock` and `R/renv/` layout. Their location does not by itself demonstrate project-root automatic restoration; establish and document a reproducible package environment.
4. Prepare the GeoPackage files and make them accessible to the account running Shiny.
5. Select a durable SQLite path with restricted filesystem access. Back up any existing database before first launch; `init_db_tables()` can create or alter schema during startup.
6. Apply hosting-layer access control and HTTPS. Review data-protection and medical-data governance requirements for the intended use.
7. Test with synthetic data on a nonproduction instance, then run `shiny::runApp(".")` from the project root.

## 3. Runtime configuration: `config.yaml`

```yaml
app:
  version: "2.0.0"
data_dir: "raw_data"
database:
  type: "sqlite"
  path: "data/report_database.db"
  table: "reports"
```

| Setting | What it does |
|---|---|
| `app.version` | Displays the version badge in the application header. |
| `data_dir` | Directory holding each configured country GeoPackage. |
| `database.type` | Currently informational: `get_db_connection()` opens SQLite regardless of an alternative value. |
| `database.path` | Path to the local SQLite store; resolved relative to the project root. |
| `database.table` | Name of the reports table; defaults to `reports`. |

Do not change `database.type` to `odbc` and assume an external connection will work: external database support is not implemented in this source. If you need an external database, plan a separate implementation and validation effort. Avoid placing the SQLite file in a publicly served `www/` directory.

## 4. Geographic configuration: `config.json`

The shipped Argentina configuration uses the ordered keys `country`, `level1`, `level2`, `level3` and a `mapping` for levels 1 through 3.

| Level | Configured layer | ID field | Parent field | Label field | Code length |
|---|---|---|---|---|---|
| `level1` | `Province` | `cpr` | — | `nam` | 2 |
| `level2` | `Department` | `cde` | `cpr` | `nam` | 5 |
| `level3` | `Fraction` | `cod_indec` | `cde` | `cod_indec` | 7 |

Additional options are `db_column` (the source mapping currently contains `Level1`, `Level2`, `Level3`), `ui_label` for the dropdown label, `file_name` for the GeoPackage, and the ordered `levels` list. These settings do **not** rename the physical SQLite columns (`level1`, `level2`, `level3`).

### Adding or replacing country boundaries

1. Acquire authoritative boundary data and verify permission to use and distribute it.
2. Define up to three geographic levels compatible with the existing UI. For each level, create an indexed, unique code; ensure every lower-level feature maps to a valid parent code.
3. Build and validate a GeoPackage with layers and columns matching the intended `mapping`; preserve leading zeros in codes.
4. Put the GeoPackage in `data_dir` and set its exact `file_name` in the new top-level country entry.
5. Configure `layer_name`, `spatial_id`, `parent_col`, `name_col`, `db_column`, `code_length`, and `ui_label`. Ensure mapped `db_column` values match how `get_level_key_by_db_column()` is called by the application.
6. Test country selection, the first two dropdowns, shape loading, finest-area clicks, and the final stored `level3` value against known synthetic reports.
7. Inspect the map initial viewpoint. This source initializes the map over Argentina; a new country may require adjusting that default in `R/report_geolocation.R`.

**Important limitations:** the code handles three geographic tiers, uses a dynamic spatial SQL query whose values are interpolated, and may assign EPSG:4326 to geometry with missing CRS metadata. Validate actual coordinate systems rather than assigning a CRS by assumption.

### New country configuration checklist

Step 1. Prepare a country GeoPackage with one layer for each configured administrative level. Each layer requires a unique identifier and a display-name field. Child layers also require an identifier linking each area to its parent.

Step 2. Copy the verified GeoPackage to raw_data/ and add the country entry to config.json. Set file_name, ordered levels, layer_name, spatial_id, name_col, parent_col (where needed), db_column, code_length and ui_label to the actual layer schema.

Step 3. Preserve geographic identifiers as text and check leading zeros. Ensure country, level1, level2 and level3 mappings correspond to the reporting fields expected by the app. Test representative parents, children and finest-area codes.

Step 4. Review the initial Leaflet map view in R/report_geolocation.R. It is currently centred on Argentina and may need adjustment for a different country. Update visible labels only after the underlying geographic mapping works.

Step 5. Run the app with synthetic records. Confirm that the country selector, cascading lists, polygon selection, report storage and current-session export reflect the correct area and identifier. The Argentina configuration is a reference example, not proof that another country is valid without testing.

### External database integration status

Connecting directly to a new external database is not currently a config.yaml-only option. If an institution requires SQL Server, PostgreSQL or another managed source, development must supply a suitable connector and destination mapping. Any change must be reviewed for credentials, permissions, schema compatibility, transactions and incident recovery before production use.

## 5. Local database management

The application initializes a `reports` table containing case identifiers, dates, demographics, three geographic levels, clinical description/diagnosis, submission times, reporter email, and institution. `id_code` is a UUID primary key generated by the app. When an existing table is opened, missing columns may be added and missing `submitted_at` values copied from `confirmation_time`.

**Before configuring a new institution:** choose the authorised storage location and backup policy; restrict direct access to the SQLite file; back up existing stores before version changes; test restore operations; establish retention and incident-response processes. Avoid moving a live SQLite database through a general shared network folder for concurrent writes. For multi-user hosted reporting, verify transaction behaviour and concurrent load with the actual deployment setup.

The shipped code has **no administrative history-download UI**. A data custodian needing an authorised historical extract must use a separately governed workflow outside the normal form, not the end-user session download.

## 6. UI and institutional terminology

Use `www/config.css` for theme colors, form layout and control styling; `R/report_form.R` for product heading/field text; `R/report_geolocation.R` for map and location controls; `config.json` for geographic labels. Align version badge and published documentation when release metadata changes. Do not assume that changing the UI label changes the stored field name or database schema.

For a new institution, also verify translations and clinical vocabulary, authorised values of sex categories, legal reporting requirements, consent/privacy notices and access restrictions. The current form has fixed English labels and fixed fields; local changes may require source updates and tests.

## 7. Release verification

| Area | Acceptance check |
|---|---|
| Startup | R and packages load; app can open configured GeoPackage and a writable, backed-up local database. |
| Data | One synthetic confirmed report produces exactly one table row and an expected UUID. |
| Validation | Missing required fields and reversed birth/consultation dates are rejected; symptom-onset chronology limitations are recorded as issues. |
| Geography | Parent-child areas and final polygon selection match configured IDs; CRS is valid. |
| Export | The session CSV contains only successfully saved reports from that session. |
| Security | Authentication, TLS, file access, logging and data-retention controls are provided by deployment. |
| Failure | Database write failure shows a failure message and does not add the record to the session preview. |
| Handover | Backup/restore procedure, configuration inventory, owner contact and release version are recorded. |

## 8. Troubleshooting and change control

If no country or area appears, check `config.json`, the GeoPackage path and exact layer fields. If clicking the map does not select an area, inspect the finest-layer `spatial_id` and Leaflet shape IDs. If submission fails, verify the SQLite file is writable, the table schema and log messages; do not repeatedly submit until duplicate state is checked. If records disappear from the preview after a browser restart, that is expected: the preview is session-scoped, while confirmed reports remain in the local data store.

Do not claim automatic future-date or symptom-onset chronology enforcement beyond what the current implementation performs. Do not publish the earlier administrator-password or email-based history-download instructions; those features are absent from this source.

## 9. Ownership boundaries

Institutional administrators configure hosting, storage, access, geography and clinical governance. Developers maintain form logic, spatial utilities, database migrations and tests. End users only report cases and download their session CSV. These roles should be expressed in the institution's operational procedures, not assumed to be enforced by the application itself.
