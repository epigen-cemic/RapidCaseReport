# RapidCaseReport | Local Data Store Reference

**Revision:** 2026-11-23. This operational reference describes the current SQLite-only implementation; it does not describe an external database adapter.

## Default configuration

`config.yaml` contains:

```yaml
database:
  type: "sqlite"
  path: "data/report_database.db"
  table: "reports"
```

On startup, `global.R` calls `get_db_connection(config)`. This creates the containing directory if missing, opens a SQLite pool, and calls `init_db_tables()` to create `reports` or extend a legacy table. **Startup may modify data-store schema.** Always back up a current database before running a new source release against it.

The `reports` table contains a generated UUID and the individual case/reporting fields listed in [Data Dictionary](Data_Dictionary_RapidCaseReport.md). Its default location is relative to the host application's project directory, **not the browser user's device**.

## Storage operations

- **Submission:** `insert_to_db()` appends a report to the configured table. A failed append returns `FALSE` and should not populate the session preview.
- **Session CSV:** *Download Current Session CSV* downloads `form_records`, which includes confirmed submissions made during the current Shiny session only.
- **Historical data:** there is no end-user or administrator historical download feature in the application. Institutional exports require a separately governed administrative process.
- **No production fallback:** the app does not automatically switch to a CSV file or external database after a storage error.

## Administration safeguards

Restrict filesystem access, encrypt backups as required by institutional policy, monitor disk space, verify backups can be restored, and avoid committing SQLite files or patient data. Hosted multi-user deployments must verify concurrent-write reliability and durable persistence. Changing `database.type` alone does not make a non-SQLite connector work.

**Initialization procedure:** use the built-in `get_db_connection()` and `init_db_tables()` workflow documented above. No separate initialization script is required.

See [Institutional Setup Guide](INSTITUTIONAL_SETUP_GUIDE.md).
