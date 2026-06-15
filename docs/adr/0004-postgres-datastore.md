# Postgres as the datastore

We use PostgreSQL rather than SQLite. The architecture runs two processes that write concurrently — the web server (persisting Member libraries/wishlists) and the background enrichment worker (persisting App metadata during cache backfill). SQLite serializes writes behind a database-level lock and would contend badly under the enrichment burst; Postgres handles concurrent writers cleanly.

Postgres is also the database the boot.dev SQL module targets, drops into Docker Compose alongside the app and broker, and makes the project a more convincing deployed backend artifact.

## Consequences

- Local development requires a running Postgres (via Docker Compose), not just a file. Acceptable since the project uses Docker regardless.
