# PRD — Spotify Self-Analytics ETL Pipeline

> **Status:** Ready for implementation  
> **Publish to:** GitHub Issues with `needs-triage` label once remote is configured

---

## Problem Statement

A data engineer building a portfolio cannot demonstrate end-to-end pipeline skills from a
description alone. Interviewers need to see working evidence of: OAuth API extraction,
a raw landing layer, idempotent loading into a relational database, SQL transformation
with a modeling framework, and workflow orchestration with failure alerting — all on
cloud infrastructure provisioned as code.

Without a project that wires all of these together on real data, a candidate cannot
credibly discuss the architectural decisions, failure modes, or operational concerns
that distinguish a junior data engineer from someone who has only done coursework.

---

## Solution

A production-style ETL pipeline that extracts personal music data from the Spotify Web API
on a daily schedule, lands raw JSON to Amazon S3, loads structured records into RDS
PostgreSQL, models the data through staging → intermediate → mart layers using dbt Core,
and orchestrates every step with Apache Airflow — deployed on AWS and provisioned entirely
with Terraform.

The pipeline produces four analyst-ready mart tables that answer real questions about
personal listening habits, and can be demoed live to an interviewer in under two minutes
using real personal data.

---

## User Stories

### Infrastructure

1. As a data engineer, I want all AWS resources provisioned by Terraform, so that the entire
   environment can be recreated from scratch with a single command and reviewers can inspect
   the infrastructure as code.

2. As a data engineer, I want infrastructure state stored in a remote S3 backend, so that
   Terraform state is not lost if my local machine is unavailable.

3. As a data engineer, I want the RDS instance isolated in a private subnet, so that the
   database is never directly reachable from the public internet.

4. As a data engineer, I want SSH access to the EC2 instance restricted to my IP address only,
   so that the Airflow host is not exposed to the public internet.

5. As a data engineer, I want the EC2 instance to access S3 and RDS via an IAM instance role,
   so that no AWS credentials are stored in code or on disk.

6. As a data engineer, I want Terraform to output the EC2 public IP, RDS endpoint, and S3
   bucket name after apply, so that I can configure dependent services without manually
   looking up resource values in the AWS console.

### Spotify Authentication

7. As a data engineer, I want to authenticate with the Spotify Web API using the Authorization
   Code Flow, so that I can access personal library endpoints that require user consent.

8. As a data engineer, I want the OAuth token to be cached to disk and auto-refreshed, so that
   the pipeline can run headlessly on EC2 without requiring a browser interaction on each run.

9. As a data engineer, I want credentials stored in environment variables and never in code,
   so that the repository can be made public without leaking secrets.

10. As a data engineer, I want to request only the minimum OAuth scopes needed, so that the
    application follows the principle of least privilege.

### Extraction

11. As a data engineer, I want saved tracks extracted using a watermark on `added_at`, so that
    each run only fetches records newer than the last successful extraction.

12. As a data engineer, I want saved albums extracted using the same watermark pattern as saved
    tracks, so that both endpoints benefit from efficient incremental loading.

13. As a data engineer, I want playlists and their tracks extracted with a full refresh on every
    run, so that tracks removed from a playlist are correctly reflected in the pipeline.

14. As a data engineer, I want artist metadata fetched in batches of 50 IDs per API call, so
    that the extraction respects Spotify's batch endpoint limits and minimises rate-limit risk.

15. As a data engineer, I want all three extraction tasks in the EL DAG to run in parallel, so
    that the total extraction time is bounded by the slowest endpoint, not their sum.

16. As a data engineer, I want paginated responses handled automatically inside each extractor,
    so that no records are silently dropped when a library exceeds 50 items.

### Raw Landing Layer

17. As a data engineer, I want every raw API response landed to S3 as a JSON file before any
    transformation occurs, so that the original data is preserved and can be reprocessed if
    transformation logic changes.

18. As a data engineer, I want raw files stored at a date-partitioned S3 prefix
    (`raw/spotify/{endpoint}/YYYY-MM-DD/response.json`), so that any specific run's raw data
    can be located and reprocessed by date.

19. As a data engineer, I want writing the same file twice to overwrite the previous version
    without error, so that the landing step is idempotent and reruns are safe.

20. As a data engineer, I want each raw file to include an `extracted_at` timestamp in its
    payload, so that I can audit when each snapshot was taken independently of the file's
    S3 modification time.

### Loading to RDS

21. As a data engineer, I want all loading to RDS performed with an upsert
    (`INSERT ... ON CONFLICT DO UPDATE`), so that running the load step twice on the same
    data produces no duplicate rows.

22. As a data engineer, I want watermark state stored in a dedicated `pipeline_watermarks`
    table in RDS, so that each incremental run knows exactly where the previous run left off.

23. As a data engineer, I want all RDS writes wrapped in a transaction, so that a crash
    mid-load leaves the table in its previous consistent state rather than a partial one.

24. As a data engineer, I want artist metadata loaded after saved tracks and albums, so that
    all artist IDs referenced in those tables are available for the batch artist lookup.

### Orchestration

25. As a data engineer, I want the EL DAG to run on a daily schedule at midnight UTC, so that
    mart tables are refreshed with each new day's saves by the time I check them in the morning.

26. As a data engineer, I want the transform DAG to wait for the EL DAG's load step to
    succeed before running dbt, so that dbt never runs against a partially-loaded dataset.

27. As a data engineer, I want failed tasks to retry automatically with a delay, so that
    transient errors (network timeouts, API rate limits) resolve without manual intervention.

28. As a data engineer, I want `catchup=False` on both DAGs, so that unpausing a DAG does not
    trigger a backfill of every missed run since `start_date`.

29. As a data engineer, I want both DAGs tagged clearly, so that they are easy to filter in
    the Airflow UI when the DAG list grows.

### Failure Alerting

30. As a data engineer, I want a Slack message sent automatically whenever any task fails, so
    that I am notified without having to monitor the Airflow UI continuously.

31. As a data engineer, I want the Slack alert to include the DAG name, task name, run ID, and
    a direct link to the task log, so that I can diagnose the failure from the notification
    without logging into the Airflow UI first.

### dbt Transformation

32. As a data engineer, I want all staging models to be views over a single source table each,
    so that they stay fresh automatically and do not duplicate storage.

33. As a data engineer, I want intermediate models materialized as ephemeral CTEs, so that
    join logic is reusable across mart models without creating intermediate tables in the
    database.

34. As a data engineer, I want all mart models materialized as tables, so that analyst queries
    against the marts are fast regardless of the complexity of the upstream SQL.

35. As a data engineer, I want all dbt models to reference sources and upstream models with
    `{{ source() }}` and `{{ ref() }}`, so that dbt can enforce the correct build order and
    generate an accurate lineage graph.

36. As a data engineer, I want `dbt test` to run after `dbt run` in the transform DAG, so that
    a data quality failure causes the DAG task to fail and triggers the Slack alert.

### Mart Tables

37. As a data analyst, I want a mart table showing my most-saved artists broken down by month,
    so that I can identify which artists I was most engaged with during specific time periods.

38. As a data analyst, I want a mart table showing the top genres in my library ranked by track
    count, so that I can understand the overall shape of my musical taste.

39. As a data analyst, I want a mart table showing how many tracks and albums I saved per week
    and per month over time, so that I can see whether my library is growing faster or slower
    across different periods.

40. As a data analyst, I want a mart table showing which artists and genres dominate each of my
    playlists, so that I can understand the character of each playlist beyond just its name.

41. As a data analyst, I want genre data derived from artist metadata rather than track metadata,
    so that genres are consistent (Spotify assigns genres to artists, not individual tracks).

### Data Quality

42. As a data engineer, I want `not_null` and `unique` tests on every primary key column in
    every staging model, so that data integrity violations are caught before they corrupt mart
    tables.

43. As a data engineer, I want the `pipeline_watermarks` table updated only after a successful
    load, so that a failed run does not advance the watermark and cause records to be skipped
    on the next run.

---

## Implementation Decisions

### Modules

**SpotifyAuthenticator**
Wraps `SpotifyOAuth` configuration behind a single factory function. Reads credentials from
environment variables. Manages the token cache path. Returns a ready-to-use Spotipy client.
This is the only module that touches OAuth — all extractors receive a client, never credentials.

**WatermarkStore**
Encapsulates all reads and writes to the `pipeline_watermarks` table. Exposes two operations:
read the last watermark for an endpoint, and write a new watermark after a successful load.
Hiding this behind its own interface means the watermark storage mechanism can change
(e.g. move to AWS SSM Parameter Store) without touching any extractor.

**BaseExtractor + concrete extractors (SavedTracks, SavedAlbums, Playlists, ArtistMetadata)**
Each extractor inherits from a common base that enforces the `extract(**kwargs) -> dict`
contract. Pagination is handled entirely inside the extractor — callers never see the
Spotify pagination model. The watermark parameter is optional; extractors that do full
refreshes (Playlists) ignore it.

**S3Loader**
Accepts a bucket name at construction. Exposes a single `land(endpoint, data, run_date)`
method that constructs the date-partitioned key and writes JSON. All S3 interaction is
contained here — no other module imports boto3.

**RDSLoader**
Accepts a DSN string at construction. Exposes a single `upsert(table, rows, conflict_key)`
method that generates the `INSERT ... ON CONFLICT` SQL dynamically from the row shape.
All psycopg2 interaction is contained here — no other module opens database connections.

**EL DAG**
Four tasks: three parallel extraction tasks (one per primary endpoint) and one load task
that depends on all three. The load task also triggers artist metadata extraction using
IDs collected from the just-loaded track and album tables.

**Transform DAG**
Three tasks: an `ExternalTaskSensor` that blocks until the EL DAG's load step succeeds,
a `BashOperator` that runs `dbt run`, and a `BashOperator` that runs `dbt test`.

**SlackFailureCallback**
A standalone function passed as `on_failure_callback` in both DAGs' `default_args`.
Reads the webhook URL from an environment variable and POSTs a structured message using
the Airflow task context.

**dbt staging layer**
One model per source table. Each model renames columns to a consistent convention and
casts `added_at` from text to timestamp. No joins, no aggregations.

**dbt intermediate layer**
Two models: one that enriches tracks with their artist metadata, one that enriches
playlist track membership with playlist and track/artist detail. Both are ephemeral.

**dbt mart layer**
Four models, each answering one analytical question (see User Stories 37–40). Each mart
reads from intermediate models only — never directly from staging or sources.

**Terraform modules**
Five focused modules: networking (VPC, subnets, routing), compute (EC2, security group,
key pair), database (RDS, subnet group, security group), storage (S3 bucket), iam
(instance role and policy). Modules are wired together in `main.tf`; cross-module
dependencies are passed as outputs.

### Architectural Decisions

- Self-hosted Airflow on EC2 over MWAA — cost: MWAA minimum ~$300/month vs ~$30/month
  for a `t3.medium`. See ADR 0001.
- RDS PostgreSQL over Redshift — personal Spotify data volume does not justify a columnar
  warehouse; PostgreSQL's `unnest` and `string_to_array` functions handle genre expansion
  natively.
- Hybrid incremental strategy — watermark for saved tracks and albums (append-only),
  full refresh + upsert for playlists (membership can decrease).
- Two DAGs over one — clean separation of EL ownership (data engineer) from transform
  ownership (analytics engineer); the `ExternalTaskSensor` is the explicit contract
  between them.
- Genres stored as comma-separated text in RDS, unnested in dbt — avoids a separate
  `artist_genres` junction table while keeping the raw layer faithful to the API response.

### Schema

Five raw tables loaded by Python: `raw_saved_tracks`, `raw_saved_albums`, `raw_playlists`,
`raw_playlist_tracks`, `raw_artists`. One control table: `pipeline_watermarks`.
All primary keys are Spotify string IDs. `added_at` stored as text in raw tables and cast
to timestamp in staging models.

---

## Testing Decisions

**What makes a good test here**
Test observable outputs given controlled inputs — not the internal steps taken to produce them.
For an extractor, the observable output is the shape and content of the dict it returns.
For a loader, the observable output is the database or S3 state after the call.
Do not assert on which internal methods were called; assert on what changed in the world.

**Modules to test**

*WatermarkStore* — unit tests with a real test database (not mocked). Assert that reading
from an empty table returns None, that writing a watermark persists correctly, and that a
second write updates rather than duplicates. These tests are fast and the real SQL
behaviour matters.

*RDSLoader.upsert* — integration test with a real test database. Seed a table, call upsert
with overlapping rows, assert row counts and updated values. A mock here would not catch
the actual ON CONFLICT SQL behaviour.

*SavedTracksExtractor / SavedAlbumsExtractor* — unit tests with a mocked Spotipy client.
Return a controlled paginated response from the mock. Assert that all pages are collected,
that the watermark filter drops the correct items, and that `extracted_at` is present in
the output. Mocking is appropriate here because the Spotify API is external.

*PlaylistsExtractor* — unit tests with mocked client. Assert that nested track pagination
is followed and that tracks are attached to the correct playlist in the output.

*S3Loader* — unit tests with mocked boto3. Assert that `put_object` is called with the
correct key for a given endpoint and date, and that the body is valid JSON.

*SlackFailureCallback* — unit test with mocked `requests.post`. Assert that the correct
URL and message shape are sent for a given Airflow context dict.

*dbt models* — use dbt's built-in test framework. `not_null` and `unique` on all primary
key columns in staging models. Row-count assertion tests on mart models once data is loaded
(assert each mart returns at least one row).

**Modules not tested**

`SpotifyAuthenticator` — OAuth browser redirect cannot be unit tested meaningfully. Tested
manually during Milestone 3.

Terraform modules — infrastructure correctness verified by `terraform plan` output and
post-apply smoke tests (SSH in, confirm RDS reachable from EC2).

Airflow DAG structure — `python dag_file.py` import test catches syntax and import errors.
Full DAG execution tested by manual trigger in Milestone 5 and 7.

---

## Out of Scope

- **Audio features** (`/audio-features/{id}`) — endpoint availability unverified for new
  developer apps as of late 2024. Architecture is designed to add this as a single new
  extractor + staging model if the endpoint is accessible. Tracked as Milestone 9 stretch goal.
- **Recently played / top tracks / top artists** — restricted by Spotify for new apps.
- **Dashboard or visualisation layer** — mart tables are the output. Connecting a BI tool
  (Metabase, Grafana, Superset) is a separate project.
- **Multi-user support** — pipeline is scoped to a single Spotify account. The OAuth token
  cache is a single file; no multi-tenancy is designed.
- **Backfilling historical data** — `catchup=False` on both DAGs. Historical data is loaded
  on the first full run (no watermark). Scheduled reruns are incremental only.
- **MWAA or managed Airflow** — evaluated and excluded on cost grounds (ADR 0001).
- **dbt Cloud** — dbt Core on EC2 is sufficient; dbt Cloud adds cost and an external
  dependency without benefit at this scale.
- **CI/CD pipeline** — no automated deployment on push. Deployment is manual via SSH.

---

## Further Notes

**OAuth headless deployment**
The Spotify Authorization Code Flow requires a browser redirect on first auth. This must be
run locally. The resulting token cache file is then copied to EC2 via `scp`. Every
subsequent run uses the refresh token silently. This is a known constraint of personal-data
OAuth flows in headless environments and should be documented in the README.

**Interview demo path**
The four mart tables can be queried live in a psql session or a simple SQL client.
Prepared queries for each mart make it easy to show real results in under two minutes
without requiring a dashboard. Keep these queries in a `demo/` directory.

**Spotify endpoint verification**
Before implementing the audio features extractor (Milestone 9), verify access by calling
`GET /audio-features/{id}` with a valid track ID using the developer app. A 403 response
means the endpoint is restricted for new apps. A 200 means it is available and the
stretch goal is unblocked.

**Cost estimate**
Running continuously: EC2 `t3.medium` ~$30/month + RDS `db.t3.micro` ~$15/month +
S3 (negligible for this data volume) = ~$45/month. Stop the EC2 instance when not
actively developing to reduce cost.
