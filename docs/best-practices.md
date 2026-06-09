# Best Practices by Tool

Reference this while implementing each milestone. These are the habits that separate
"it works on my machine" from production-quality work that impresses interviewers.

---

## Python (General)

**Environment variables, never hardcoded secrets**
Always read credentials with `os.environ["KEY"]` — never write them directly in code.
If the key is missing you get a clear `KeyError` immediately rather than a silent wrong value.

**Type hints on function signatures**
```python
def extract(self, after: datetime | None = None) -> dict:
```
They serve as documentation and catch mistakes before runtime.

**Validate at boundaries, trust internally**
Only check inputs at the edges of your system (API responses, user input, env vars).
Don't add defensive checks inside functions you wrote and control.

**Use `default=str` when serializing to JSON**
```python
json.dumps(data, default=str)
```
Datetime objects aren't JSON-serializable by default — `default=str` converts them
rather than crashing.

---

## Spotipy / Spotify API

**Request only the scopes you need**
The principle of least privilege — don't request `user-read-playback-state` if you
only need `user-library-read`. Fewer scopes = smaller blast radius if credentials leak.

**Never store tokens in code or git**
The token cache file (`cache_path`) contains your refresh token. Treat it like a password.
Add `*.spotify_cache` to `.gitignore`.

**Handle pagination consistently**
The Spotify API returns max 50 items per request. Every extractor must loop until
`response["next"]` is `None`. Missing pagination means silently incomplete data.

**Respect rate limits**
Spotify returns HTTP 429 with a `Retry-After` header when rate-limited.
Spotipy handles basic retries, but add a `try/except` around batch calls and
log when you hit a limit — it helps debugging.

**Batch artist lookups**
`/artists` accepts up to 50 IDs per call. Never call it one ID at a time —
that burns your rate limit quota and is 50x slower.

---

## Apache Airflow

**Keep DAG files thin**
The DAG file is parsed by the Airflow scheduler every 30 seconds. Heavy imports or
logic at module level slows the whole scheduler. Put all logic inside the callable
functions, not at the top of the file.

**All tasks must be idempotent**
Running the same task twice on the same date should produce the same result.
This is what makes reruns safe. The upsert pattern in `RDSLoader` enforces this
on the database side — make sure your extractors and S3 writes also follow it
(writing to the same S3 key twice is fine; it overwrites).

**Use `catchup=False` on new DAGs**
Without it, Airflow will try to backfill every missed run since `start_date` the
first time you unpause the DAG. That will fire dozens of API calls at once.

**Set retries and retry_delay on every DAG**
External API calls fail. A `retries=2, retry_delay=timedelta(minutes=5)` costs nothing
and prevents one transient error from failing the whole pipeline.

**One task = one logical unit of work**
Don't write a single task that extracts, transforms, and loads. If it fails, you
can't tell which step broke and you have to redo everything. Keep extraction,
loading, and transformation as separate tasks.

**Use XCom sparingly**
XCom (cross-task communication) is for small values like a run ID or a count.
Never pass a full dataset through XCom — use S3 as the handoff layer between tasks.

**Test DAGs before deploying**
```bash
python airflow/dags/spotify_el_dag.py
```
If it runs without error, the DAG file has no import or syntax issues.

---

## dbt

**Always use `{{ ref() }}` and `{{ source() }}`**
Never hardcode table names like `FROM public.raw_saved_tracks`.
`{{ source() }}` enables source freshness checks and lineage tracking.
`{{ ref() }}` tells dbt the build order — it won't run a model before its dependencies.

**Staging models are views, marts are tables**
Already set in `dbt_project.yml`. Views stay fresh automatically; materializing
staging as tables wastes storage on data you'll rebuild anyway. Marts are tables
because analysts query them — they need to be fast.

**Intermediate models are ephemeral**
`ephemeral` means dbt inlines them as CTEs rather than creating real objects.
Use this for intermediate logic that no one queries directly.

**Add tests to every model**
At minimum: `not_null` and `unique` on every primary key column.
```yaml
columns:
  - name: track_id
    tests:
      - not_null
      - unique
```
These tests run with `dbt test` and catch data quality issues before they reach marts.

**`dbt run` then `dbt test` — always in that order**
Running tests on stale models gives false confidence. Always rebuild first.

**Never put business logic in staging models**
Staging = rename + cast + deduplicate. Joins, calculations, and aggregations belong
in intermediate or mart models. This keeps staging models easy to audit.

**Use `dbt compile` to debug SQL**
`dbt compile` renders your Jinja templates into raw SQL without running them.
Paste the output into a SQL client to test before running the full model.

---

## PostgreSQL / psycopg2

**Never use f-strings to build SQL**
```python
# WRONG — SQL injection risk
cur.execute(f"INSERT INTO {table} VALUES ({value})")

# RIGHT — parameterized query
cur.execute("INSERT INTO my_table VALUES (%s)", (value,))
```
Use `execute_values` for bulk inserts — it's significantly faster than looping.

**Always use a transaction (`with conn:`)**
```python
with conn:
    with conn.cursor() as cur:
        cur.execute(...)
# conn.commit() happens automatically; rolls back on exception
```
Without a transaction, a crash mid-insert leaves your table in a partial state.

**Always close connections**
Call `conn.close()` after each operation, or use a context manager.
Unclosed connections accumulate and exhaust the RDS connection limit.

**Add indexes on columns you join or filter on**
```sql
CREATE INDEX ON raw_saved_tracks (artist_id);
CREATE INDEX ON raw_playlist_tracks (playlist_id);
```
Without indexes, dbt's joins do full table scans — fine now, slow as data grows.

**Use `ON CONFLICT DO UPDATE`, not DELETE + INSERT**
The upsert pattern is atomic and safe under concurrent writes.
DELETE + INSERT creates a window where the row doesn't exist.

---

## Terraform

**Never commit `terraform.tfstate` or `terraform.tfstate.backup`**
Add both to `.gitignore`. State files contain plaintext secrets (RDS passwords, etc.).
Use the S3 remote backend to store state safely.

**Never commit `*.tfvars` files with real values**
Keep a `terraform.tfvars.example` in git with placeholder values, and keep the real
`terraform.tfvars` gitignored — same pattern as `.env.example`.

**Mark sensitive variables as `sensitive = true`**
```hcl
variable "db_password" {
  sensitive = true
}
```
Terraform won't print them in plan/apply output.

**Always run `terraform plan` before `terraform apply`**
Read the plan output carefully — confirm no unexpected destroys before applying.
A `~` means update-in-place, a `-/+` means destroy and recreate (brief downtime).

**Pin provider versions**
```hcl
aws = {
  version = "~> 5.0"
}
```
Without pinning, `terraform init` can pull a new provider version that breaks your config.

**Keep modules focused**
One module per logical resource group (networking, compute, database, etc.).
Modules should output the values other modules need — never reach across modules
by hardcoding resource IDs.

**Use `terraform destroy` carefully**
It deletes everything. On a real project: take an RDS snapshot before destroying.
Always run `terraform plan -destroy` first to see exactly what will be deleted.

---

## boto3 / S3

**Use IAM roles, never hardcode AWS credentials**
On EC2, boto3 automatically uses the instance's IAM role — `boto3.client("s3")`
with no credentials argument is the correct pattern. Never put `AWS_ACCESS_KEY_ID`
in code files.

**S3 key naming convention matters**
The prefix structure `raw/spotify/{endpoint}/YYYY-MM-DD/response.json` enables:
- Partition-based queries (Athena, future use)
- Easy reprocessing of a specific date
- Clear audit trail of every extraction run

**S3 `put_object` is idempotent**
Writing to the same key twice overwrites the first file — no error, no duplicate.
This is why S3 landing is naturally idempotent.

**S3 is not a filesystem**
There are no real "folders" — the `/` in a key name is just a character.
Avoid thinking in terms of directory operations.

---

## General Data Engineering

**Raw layer is immutable**
Never modify or delete files in `raw/spotify/`. If a run produces bad data,
fix the extractor and re-land to the same key — but keep the history.
The raw layer is your source of truth and disaster recovery.

**Idempotency is not optional**
Every step — extraction, loading, transformation — must produce the same result
if run twice on the same input. This makes debugging and reprocessing safe.
Ask yourself: "if this task ran twice right now, would anything break?"

**Separate concerns between layers**
- Extractors: fetch and return raw data. No transformation.
- Loaders: write data to a destination. No business logic.
- dbt: all transformation. No data movement.
Mixing concerns makes each piece harder to test and debug independently.

**Log what you land**
After every S3 write, log the full `s3://` URI. After every upsert, log the row count.
When something breaks at 2am, these logs are how you find out which step failed
and how much data was affected.
