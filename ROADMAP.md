# Spotify Self-Analytics ETL — Roadmap

Check off each item as you complete it. Each milestone builds on the previous one —
don't skip ahead. The stretch goal (Milestone 9) can be tackled any time after Milestone 5.

---

## Milestone 1 — Infrastructure (Terraform)

Goal: one `terraform apply` provisions all AWS resources. SSH into EC2 confirmed.

### AWS account prep
- [ ] Create AWS account and enable MFA on root user
- [ ] Create an IAM user for Terraform (not root) with programmatic access
- [ ] Run `aws configure` locally with that user's credentials
- [ ] Install Terraform CLI

### Terraform modules
- [ ] Write `modules/networking` — VPC, public + private subnets, internet gateway, route tables
- [ ] Write `modules/storage` — S3 bucket with versioning enabled
- [ ] Write `modules/iam` — EC2 instance role, policy allowing S3 read/write + RDS connect
- [ ] Write `modules/database` — RDS PostgreSQL `db.t3.micro`, subnet group, security group (5432 from EC2 only)
- [ ] Write `modules/compute` — EC2 `t3.medium`, security group (SSH from your IP only), key pair

### First apply
- [ ] Run `terraform init` then `terraform plan` — review what will be created
- [ ] Run `terraform apply` — confirm all resources provision without errors
- [ ] Run `terraform output` — copy EC2 public IP, RDS endpoint, S3 bucket name into `.env`
- [ ] SSH into EC2: `ssh -i your-key.pem ec2-user@<ec2_public_ip>`
- [ ] Configure S3 remote backend and run `terraform init` again to migrate state

---

## Milestone 2 — Airflow on EC2

Goal: both DAGs visible in Airflow UI with no import errors.

### EC2 setup
- [ ] Install Docker and Docker Compose on the EC2 instance
- [ ] Write a `docker-compose.yml` for Airflow (webserver, scheduler, postgres metadata DB)
- [ ] Set Airflow environment variables (Fernet key, executor, DB connection string)

### DAGs
- [ ] Copy `airflow/dags/` and `airflow/plugins/` to EC2
- [ ] Start Airflow with `docker-compose up -d`
- [ ] Open Airflow UI (EC2 public IP:8080) — confirm both DAGs appear with no red import errors
- [ ] Pause both DAGs (don't let them run yet — data pipeline isn't ready)

---

## Milestone 3 — Spotify Authentication

Goal: OAuth flow completes locally, token cache file generated, API call returns real data.

### Developer app
- [ ] Create Spotify developer app at https://developer.spotify.com/dashboard
- [ ] Add `http://127.0.0.1:8888/callback` as a Redirect URI
- [ ] Copy Client ID and Client Secret into `.env`

### Auth flow
- [ ] Fill in `extraction/spotify_client.py` — `SpotifyOAuth` with correct scopes and redirect URI
- [ ] Run a quick test script locally that calls `get_spotify_client()` and prints `client.me()`
- [ ] Confirm the browser redirect happens, you approve, and the token cache file is created
- [ ] Verify the three scopes grant access: `GET /me/tracks`, `GET /me/albums`, `GET /me/playlists`
- [ ] **Bonus:** test `GET /audio-features/{id}` — note whether it works or returns 403

### EC2 deployment
- [ ] `scp` the token cache file to EC2 at the path set in `cache_path`
- [ ] Confirm Spotipy can silently refresh the token on EC2 (no browser needed after this)

---

## Milestone 4 — Extraction + S3 Landing

Goal: all four extractors run, raw JSON lands in S3 with the correct prefix structure.

### Watermark table
- [ ] Connect to RDS and create the `pipeline_watermarks` table (SQL in `docs/PRD.md`)
- [ ] Create all `raw_*` tables (SQL in `docs/PRD.md`)

### Extractors
- [ ] Fill in `extraction/extractors/base.py` — `__init__` and abstract `extract` method
- [ ] Fill in `extraction/extractors/saved_tracks.py` — pagination + watermark filter
- [ ] Fill in `extraction/extractors/saved_albums.py` — same pattern as saved tracks
- [ ] Fill in `extraction/extractors/playlists.py` — full refresh, nested track pagination
- [ ] Fill in `extraction/extractors/artist_metadata.py` — batch lookup (50 IDs per call)

### S3 loader
- [ ] Fill in `extraction/loaders/s3_loader.py` — `land()` with date-partitioned key
- [ ] Run each extractor locally and verify JSON lands in S3 at the correct prefix
- [ ] Check S3 console: `raw/spotify/saved_tracks/YYYY-MM-DD/response.json` exists

---

## Milestone 5 — Load to RDS

Goal: all `raw_*` tables populated. Running the load twice produces no duplicates.

### RDS loader
- [ ] Fill in `extraction/loaders/rds_loader.py` — `upsert()` with `ON CONFLICT DO UPDATE`
- [ ] Test upsert idempotency: run it twice with the same data, row counts should not increase

### EL DAG tasks
- [ ] Fill in `extract_saved_tracks` task — read watermark, extract, land to S3, update watermark
- [ ] Fill in `extract_saved_albums` task — same watermark pattern
- [ ] Fill in `extract_playlists` task — full refresh, land to S3
- [ ] Fill in `load_to_rds` task — read S3 files, flatten JSON, upsert into `raw_*` tables
- [ ] Wire up task dependencies in the DAG: `[t_tracks, t_albums, t_playlists] >> t_load`
- [ ] Trigger the EL DAG manually in Airflow UI — confirm all tasks go green
- [ ] Query RDS: `SELECT COUNT(*) FROM raw_saved_tracks;` — confirm rows exist

---

## Milestone 6 — dbt Staging + Intermediate

Goal: `dbt run` and `dbt test` pass on all staging and intermediate models.

### Setup
- [ ] Install dbt-postgres on EC2: `pip install dbt-core dbt-postgres`
- [ ] Copy `dbt/` directory to EC2
- [ ] Create `profiles.yml` from `profiles.yml.example`, pointed at RDS
- [ ] Run `dbt debug` — confirm connection to RDS succeeds

### Staging models
- [ ] Fill in `stg_saved_tracks.sql` — rename columns, cast `added_at` to timestamp
- [ ] Fill in `stg_saved_albums.sql`
- [ ] Fill in `stg_playlists.sql`
- [ ] Fill in `stg_playlist_tracks.sql`
- [ ] Fill in `stg_artists.sql`
- [ ] Add `not_null` and `unique` tests to `sources.yml` for primary key columns
- [ ] Run `dbt run --select staging` — all staging models build successfully
- [ ] Run `dbt test --select staging` — all tests pass

### Intermediate models
- [ ] Fill in `int_tracks_with_artists.sql` — join tracks to artists
- [ ] Fill in `int_playlist_tracks_enriched.sql` — join playlist tracks to metadata
- [ ] Run `dbt run --select intermediate` — both intermediate models build successfully

---

## Milestone 7 — Mart Tables

Goal: all four mart tables build with non-empty results.

- [ ] Fill in `mart_artist_loyalty.sql` — group by month + artist
- [ ] Fill in `mart_genre_breakdown.sql` — unnest genres, count by genre
- [ ] Fill in `mart_save_velocity.sql` — union tracks + albums, group by week + month
- [ ] Fill in `mart_playlist_composition.sql` — unnest genres with lateral join
- [ ] Run `dbt run --select marts` — all four tables build
- [ ] Query each mart in psql — confirm results look correct
- [ ] Fill in `airflow/dags/spotify_transform_dag.py` — `ExternalTaskSensor`, `dbt run`, `dbt test` commands
- [ ] Trigger transform DAG manually — confirm it waits for EL DAG then runs dbt successfully

---

## Milestone 8 — End-to-End Scheduled Run + Alerting

Goal: both DAGs run automatically on schedule, Slack fires on injected failure.

### Slack alerting
- [ ] Create a Slack workspace (or use an existing one)
- [ ] Create a Slack app and enable Incoming Webhooks
- [ ] Copy the webhook URL into `.env` as `SLACK_WEBHOOK_URL`
- [ ] Fill in `airflow/plugins/callbacks/slack_callback.py`
- [ ] Inject a deliberate failure (e.g. break a task temporarily) and confirm Slack message arrives

### Scheduled runs
- [ ] Unpause both DAGs in Airflow UI
- [ ] Confirm first scheduled run triggers at midnight UTC
- [ ] Confirm EL DAG completes → transform DAG sensor fires → dbt runs → marts refresh
- [ ] Check watermark table: `SELECT * FROM pipeline_watermarks;` — timestamps updated
- [ ] Let it run for 3+ days — confirm incremental loads work correctly (no duplicate rows)

---

## Milestone 9 — Stretch Goals

- [ ] Verify `/audio-features/{id}` endpoint access on your developer app
- [ ] If accessible: add `AudioFeaturesExtractor`, `raw_audio_features` table, `stg_audio_features.sql`
- [ ] Add a `mart_audio_features_trends.sql` — average energy/danceability/tempo by month
- [ ] Add dbt `schema.yml` with column descriptions for all mart tables (documents the project)
- [ ] Add a `README.md` architecture diagram (draw.io or ASCII) showing the full data flow
- [ ] Add `dbt source freshness` check — alert if raw tables haven't been updated in 25+ hours
