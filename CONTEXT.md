# Spotify Self-Analytics ETL — Context

## Glossary

### Raw Layer
JSON files written to S3 from the Spotify API before any transformation. One file per endpoint per run, stored at `s3://{bucket}/raw/spotify/{endpoint}/YYYY-MM-DD/response.json`. Never mutated after landing.

### EL DAG
The Airflow DAG responsible for **Extract** (Spotify API → S3) and **Load** (S3 → RDS). Runs daily at midnight UTC. Owned by the data engineer role.

### Transform DAG
The Airflow DAG that triggers dbt runs after the EL DAG completes. Uses an `ExternalTaskSensor` to wait for EL DAG success. Owned by the analytics engineer role.

### Watermark
A stored timestamp representing the last successfully extracted `added_at` value for saved tracks. Used to pull only new records on incremental runs.

### Full Refresh + Upsert
The loading strategy for playlists and playlist tracks. Pulls all records from the API on every run, then upserts into RDS on a primary key. Used because playlist membership can decrease (tracks removed), making watermarks unsafe.

### Staging Model
A dbt model (prefix `stg_`) that performs light cleaning on a single raw source table: renaming columns, casting types, deduplicating. One staging model per source table.

### Intermediate Model
A dbt model (prefix `int_`) that joins or aggregates across staging models. No business logic — only structural preparation for marts.

### Mart
A dbt model (prefix `mart_`) that answers a specific analytical question. Directly consumed by analysts or dashboards.

## Confirmed Endpoints
- `/me/tracks` — saved tracks (watermark incremental on `added_at`)
- `/me/albums` — saved albums (watermark incremental on `added_at`)
- `/me/playlists` + `/playlists/{id}/tracks` — playlists and their tracks (full refresh + upsert)
- `/artists/{id}` — artist metadata including genres (fetched as enrichment for tracks/albums)

## Pending Verification
- `/audio-features/{id}` — energy, danceability, tempo per track. Architecture is designed to add this as a single new extractor + staging model if the endpoint is accessible.

## Mart Table Contracts
| Mart | Question answered |
|------|------------------|
| `mart_artist_loyalty` | Which artists appear most in saved tracks, by month |
| `mart_genre_breakdown` | Top genres in library by track count |
| `mart_save_velocity` | Tracks/albums saved per week and month |
| `mart_playlist_composition` | Artists and genres dominating each playlist |
