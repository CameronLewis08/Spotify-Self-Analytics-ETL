import psycopg2
from psycopg2.extras import execute_values


class RDSLoader:
    # TODO: write __init__ to accept a DSN string (PostgreSQL connection string)
    #   and store it as self.dsn.
    #   DSN format: "host=... dbname=... user=... password=... port=5432"

    def upsert(self, table: str, rows: list[dict], conflict_key: str) -> int:
        # Performs an idempotent INSERT ... ON CONFLICT DO UPDATE (upsert).
        # Running this twice with the same data should produce the same result — no duplicates.
        #
        # `conflict_key` is the primary key column (e.g. "track_id").
        # If a row with that key already exists, update all other columns.
        #
        # TODO: return 0 early if rows is empty.
        #
        # TODO: build the SQL dynamically from the rows' keys.
        #   - Column names: list(rows[0].keys())
        #   - Values: list of lists, one per row
        #   - UPDATE clause: "col = EXCLUDED.col" for every column except conflict_key
        #     (EXCLUDED refers to the row that was rejected by the conflict)
        #
        # Hint: use execute_values(cursor, sql, values) from psycopg2.extras —
        #   it's much faster than calling execute() in a loop.
        #
        # TODO: open a connection, run the upsert inside a transaction (use `with conn:`),
        #   close the connection, and return the number of rows processed.
        pass
