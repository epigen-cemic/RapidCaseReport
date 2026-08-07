# RapidCaseReport v2.0 – Local App Data Store Notes

RapidCaseReport v2.0 uses a local SQLite app data store by default. This is an implementation detail used to preserve confirmed submissions after they are saved.

The previous user-facing database-history download workflow has been removed. End users should only download records submitted during the current active session.

## Default local setup

The default configuration is defined in `config.yaml`:

```yaml
database:
  type: "sqlite"
  path: "data/report_database.db"
  table: "reports"
```

## Preparing an empty local data store

From the project root:

```r
source("data_prep/prepare_rapid_case_report_database.R")
```

This creates an empty `reports` table with the v2.0 schema.

## Security notes

Do not commit:

- real case records,
- test case records,
- credentials,
- `.Renviron`,
- `.RData`,
- `.Rhistory`,
- `.Rproj.user/`.

If a future production deployment needs an external database, it should be designed and tested as a separate deployment task with a clear schema, permissions model, backup plan, and security review.
