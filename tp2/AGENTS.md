# AGENTS.md

Single-file repo: `schema_food_store.sql` (food-store DB schema for "tp2", an academic assignment).

## Critical gotchas

- **This is PostgreSQL, not MySQL.** Despite the `tomySQL` folder name, the file will not run in MySQL. It uses Postgres-only features:
  - `CREATE TYPE ... AS ENUM`
  - `GENERATED ALWAYS AS IDENTITY`
  - `TIMESTAMPTZ`
  - `GENERATED ALWAYS AS (...) STORED` computed column
  - partial index (`WHERE activo = TRUE`)
  - `NUMERIC(p,s)`
- Do not "fix" these into MySQL/ANSI equivalents unless the user explicitly asks — it will break grading against the intended Postgres target.
- Run against Postgres (e.g. `psql -U <user> -d <db> -f schema_food_store.sql`); IDs are DB-generated, never insert explicit values.

## Conventions already encoded in the file

- PascalCase column names, snake_case constraint names (`fk_`, `pk_`, `uq_`, `ck_`, `idx_`).
- Every table gets a BIGINT IDENTITY PK unless it is a join/child table (e.g. `detalle_pedido` uses a composite PK).
- `ON DELETE` policy: `RESTRICT` for aggregates (`categoria`, `cliente`, `producto`), `CASCADE` for detail rows (`detalle_pedido`).
- `activo BOOLEAN DEFAULT TRUE` on master tables; indexes/keys are named explicitly, check constraints are used for numeric invariants.
- Comments are section banners (`-- TABLA: x`) — keep that style if editing.

## Workflow

- No build, test, or lint tooling in the repo. The only verification is loading the file into Postgres successfully.
- If the user asks to regenerate or update the schema, keep the whole file consistent (constraint names, FK policy, banner comments) rather than touching only one table.