# PRD — Spotify Self-Analytics ETL

## Goal

Build a production-style ETL pipeline on AWS that extracts personal music data from the Spotify Web API, lands raw JSON to S3, loads structured data into RDS PostgreSQL, models it with dbt Core, and orchestrates everything with Apache Airflow — producing four analyst-ready mart tables about personal listening habits.

---

## Architecture

```
Spotify API
    │
    ▼ (Python + Spotipy, OAuth 2.0)
Amazon S3  ← raw JSON landing layer
    │
    ▼ (Python loaders)
RDS PostgreSQL  ← structured tables
    │
    ▼ (dbt Core, BashOperator)
dbt Staging → Intermediate → Marts
    │
    ▼
mart_artist_loyalty
mart_genre_breakdown
mart_save_velocity
mart_playlist_composition
```

**Orchestration:** Two Airflow DAGs on EC2  
**Infrastructure:** Provisioned with Terraform  
**Alerting:** Slack webhook on DAG failure  

---

## Infrastructure (Terraform)

### Resources to provision

| Resource | Config |
|----------|--------|
| VPC | Single VPC with public + private subnets |
| EC2 | `t3.medium`, Amazon Linux 2, Docker + Docker Compose |
| RDS | `db.t3.micro` PostgreSQL 15, private subnet, no public access |
| S3 | One bucket: `spotify-analytics-{account-id}`, versioning enabled |
| IAM | EC2 instance role with S3 read/write + RDS connect permissions |
| Security Groups | EC2: SSH (your IP only) + outbound all; RDS: port 5432 from EC2 SG only |

### File structure

```
terraform/
├── main.tf          # provider, backend
├── variables.tf     # region, account_id, your_ip, db_password
├── outputs.tf       # ec2_public_ip, rds_endpoint, s3_bucket_name
└── modules/
    ├── networking/  # VPC, subnets, IGW, route tables
    ├── compute/     # EC2, security group, key pair
    ├── database/    # RDS, subnet group, security group
    ├── storage/     # S3 bucket, bucket policy
    └── iam/         # instance role, policy, instance profile
```

### Scaffolding

```hcl
# terraform/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # TODO: Add S3 backend after bucket is provisioned
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"
}

module "storage" {
  source     = "./modules/storage"
  account_id = var.account_id
}

module "iam" {
  source          = "./modules/iam"
  s3_bucket_arn   = module.storage.bucket_arn
}

module "database" {
  source            = "./modules/database"
  vpc_id            = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  ec2_sg_id         = module.compute.ec2_sg_id
  db_password       = var.db_password
}

module "compute" {
  source              = "./modules/compute"
  vpc_id              = module.networking.vpc_id
  public_subnet_id    = module.networking.public_subnet_id
  your_ip             = var.your_ip
  instance_profile    = module.iam.instance_profile_name
}
```

---

## Extraction Layer

### Spotify OAuth flow

Use the **Authorization Code Flow** (not Client Credentials) to access personal saved library data. Tokens must be refreshed automatically.

```python
# extraction/spotify_client.py
import spotipy
from spotipy.oauth2 import SpotifyOAuth

SCOPES = [
    "user-library-read",
    "playlist-read-private",
    "playlist-read-collaborative",
]

def get_spotify_client() -> spotipy.Spotify:
    return spotipy.Spotify(
        auth_manager=SpotifyOAuth(
            client_id=...,       # from env / AWS SSM Parameter Store
            client_secret=...,   # from env / AWS SSM Parameter Store
            redirect_uri=...,
            scope=" ".join(SCOPES),
            cache_path="/opt/airflow/.spotify_cache",
        )
    )
```

### Extractor interface

Each extractor follows the same contract: fetch from API, return raw dict.

```python
# extraction/extractors/base.py
from abc import ABC, abstractmethod
from typing import Any

class BaseExtractor(ABC):
    def __init__(self, client):
        self.client = client

    @abstractmethod
    def extract(self, **kwargs) -> dict[str, Any]:
        """Return raw API response as a dict."""
        ...
```

### Saved tracks (watermark incremental)

```python
# extraction/extractors/saved_tracks.py
from datetime import datetime
from .base import BaseExtractor

class SavedTracksExtractor(BaseExtractor):
    def extract(self, after: datetime | None = None) -> dict:
        results = {"items": [], "extracted_at": datetime.utcnow().isoformat()}
        offset = 0
        limit = 50

        while True:
            batch = self.client.current_user_saved_tracks(limit=limit, offset=offset)
            items = batch["items"]

            if after:
                items = [i for i in items if i["added_at"] > after.isoformat()]
                if len(items) < limit:
                    results["items"].extend(items)
                    break

            results["items"].extend(items)
            if not batch["next"]:
                break
            offset += limit

        return results
```

### Playlists (full refresh)

```python
# extraction/extractors/playlists.py
from .base import BaseExtractor
from datetime import datetime

class PlaylistsExtractor(BaseExtractor):
    def extract(self) -> dict:
        results = {"playlists": [], "extracted_at": datetime.utcnow().isoformat()}
        playlists = []

        response = self.client.current_user_playlists(limit=50)
        while response:
            playlists.extend(response["items"])
            response = self.client.next(response) if response["next"] else None

        for pl in playlists:
            tracks = []
            track_page = self.client.playlist_tracks(pl["id"], limit=100)
            while track_page:
                tracks.extend(track_page["items"])
                track_page = self.client.next(track_page) if track_page["next"] else None
            pl["tracks_full"] = tracks

        results["playlists"] = playlists
        return results
```

### S3 loader

```python
# extraction/loaders/s3_loader.py
import json
import boto3
from datetime import date

class S3Loader:
    def __init__(self, bucket: str):
        self.bucket = bucket
        self.s3 = boto3.client("s3")

    def land(self, endpoint: str, data: dict, run_date: date | None = None) -> str:
        run_date = run_date or date.today()
        key = f"raw/spotify/{endpoint}/{run_date.isoformat()}/response.json"
        self.s3.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=json.dumps(data, default=str),
            ContentType="application/json",
        )
        return f"s3://{self.bucket}/{key}"
```

### RDS loader (upsert)

```python
# extraction/loaders/rds_loader.py
import psycopg2
from psycopg2.extras import execute_values

class RDSLoader:
    def __init__(self, dsn: str):
        self.dsn = dsn

    def upsert(self, table: str, rows: list[dict], conflict_key: str) -> int:
        if not rows:
            return 0
        conn = psycopg2.connect(self.dsn)
        cols = list(rows[0].keys())
        values = [[r[c] for c in cols] for r in rows]
        update_cols = [c for c in cols if c != conflict_key]
        update_clause = ", ".join(f"{c} = EXCLUDED.{c}" for c in update_cols)

        sql = f"""
            INSERT INTO {table} ({', '.join(cols)})
            VALUES %s
            ON CONFLICT ({conflict_key}) DO UPDATE SET {update_clause}
        """
        with conn:
            with conn.cursor() as cur:
                execute_values(cur, sql, values)
        conn.close()
        return len(rows)
```

---

## Airflow DAGs

### Slack failure callback

```python
# airflow/plugins/callbacks/slack_callback.py
import os
import requests

def slack_failure_callback(context):
    dag_id = context["dag"].dag_id
    task_id = context["task_instance"].task_id
    run_id = context["run_id"]
    log_url = context["task_instance"].log_url

    requests.post(
        os.environ["SLACK_WEBHOOK_URL"],
        json={
            "text": f":red_circle: *{dag_id}.{task_id}* failed\nRun: `{run_id}`\n<{log_url}|View logs>"
        },
    )
```

### EL DAG

```python
# airflow/dags/spotify_el_dag.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from callbacks.slack_callback import slack_failure_callback

DEFAULT_ARGS = {
    "owner": "de",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": slack_failure_callback,
}

with DAG(
    dag_id="spotify_el",
    schedule="0 0 * * *",      # daily midnight UTC
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["spotify", "extract", "load"],
) as dag:

    def extract_saved_tracks(**context):
        # TODO: implement — call SavedTracksExtractor, land to S3
        pass

    def extract_saved_albums(**context):
        # TODO: implement — call SavedAlbumsExtractor, land to S3
        pass

    def extract_playlists(**context):
        # TODO: implement — call PlaylistsExtractor, land to S3
        pass

    def load_to_rds(**context):
        # TODO: implement — read from S3, upsert into RDS staging tables
        pass

    t_tracks  = PythonOperator(task_id="extract_saved_tracks",  python_callable=extract_saved_tracks)
    t_albums  = PythonOperator(task_id="extract_saved_albums",  python_callable=extract_saved_albums)
    t_playlists = PythonOperator(task_id="extract_playlists",   python_callable=extract_playlists)
    t_load    = PythonOperator(task_id="load_to_rds",           python_callable=load_to_rds)

    [t_tracks, t_albums, t_playlists] >> t_load
```

### Transform DAG

```python
# airflow/dags/spotify_transform_dag.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.sensors.external_task import ExternalTaskSensor
from callbacks.slack_callback import slack_failure_callback

DEFAULT_ARGS = {
    "owner": "ae",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": slack_failure_callback,
}

with DAG(
    dag_id="spotify_transform",
    schedule="0 0 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["spotify", "dbt", "transform"],
) as dag:

    wait_for_el = ExternalTaskSensor(
        task_id="wait_for_el_dag",
        external_dag_id="spotify_el",
        external_task_id="load_to_rds",
        timeout=3600,
        poke_interval=60,
    )

    run_dbt = BashOperator(
        task_id="run_dbt",
        bash_command="cd /opt/dbt/spotify && dbt run --profiles-dir /opt/dbt",
    )

    test_dbt = BashOperator(
        task_id="test_dbt",
        bash_command="cd /opt/dbt/spotify && dbt test --profiles-dir /opt/dbt",
    )

    wait_for_el >> run_dbt >> test_dbt
```

---

## dbt Layer

### Project structure

```
dbt/
├── dbt_project.yml
├── profiles.yml.example
├── models/
│   ├── staging/
│   │   ├── sources.yml           # declares raw RDS tables as sources
│   │   ├── stg_saved_tracks.sql
│   │   ├── stg_saved_albums.sql
│   │   ├── stg_playlists.sql
│   │   ├── stg_playlist_tracks.sql
│   │   └── stg_artists.sql
│   ├── intermediate/
│   │   ├── int_tracks_with_artists.sql
│   │   └── int_playlist_tracks_enriched.sql
│   └── marts/
│       ├── mart_artist_loyalty.sql
│       ├── mart_genre_breakdown.sql
│       ├── mart_save_velocity.sql
│       └── mart_playlist_composition.sql
└── tests/
    └── assert_no_duplicate_track_ids.sql
```

### Staging model pattern

```sql
-- dbt/models/staging/stg_saved_tracks.sql
with source as (
    select * from {{ source('spotify_raw', 'raw_saved_tracks') }}
),

renamed as (
    select
        track_id,
        track_name,
        artist_id,
        album_id,
        added_at::timestamp             as added_at,
        duration_ms,
        explicit,
        popularity,
        _loaded_at
    from source
)

select * from renamed
```

### Intermediate model pattern

```sql
-- dbt/models/intermediate/int_tracks_with_artists.sql
with tracks as (
    select * from {{ ref('stg_saved_tracks') }}
),

artists as (
    select * from {{ ref('stg_artists') }}
)

select
    t.track_id,
    t.track_name,
    t.added_at,
    t.popularity,
    a.artist_id,
    a.artist_name,
    a.genres
from tracks t
left join artists a using (artist_id)
```

### Mart scaffolds

```sql
-- dbt/models/marts/mart_artist_loyalty.sql
-- Question: Which artists appear most in saved tracks, by month?
with base as (
    select * from {{ ref('int_tracks_with_artists') }}
)

select
    date_trunc('month', added_at)   as month,
    artist_id,
    artist_name,
    count(*)                        as track_count,
    min(added_at)                   as first_saved_at
from base
group by 1, 2, 3
order by 1 desc, 4 desc
```

```sql
-- dbt/models/marts/mart_genre_breakdown.sql
-- Question: Top genres in library by track count?
with exploded as (
    select
        track_id,
        added_at,
        unnest(string_to_array(genres, ',')) as genre
    from {{ ref('int_tracks_with_artists') }}
    where genres is not null
)

select
    trim(genre)         as genre,
    count(*)            as track_count,
    min(added_at)       as first_appearance
from exploded
group by 1
order by 2 desc
```

```sql
-- dbt/models/marts/mart_save_velocity.sql
-- Question: How many tracks/albums saved per week and month?
with tracks as (
    select added_at, 'track' as content_type from {{ ref('stg_saved_tracks') }}
),
albums as (
    select added_at, 'album' as content_type from {{ ref('stg_saved_albums') }}
),
combined as (
    select * from tracks
    union all
    select * from albums
)

select
    date_trunc('week',  added_at)   as week,
    date_trunc('month', added_at)   as month,
    content_type,
    count(*)                        as saves
from combined
group by 1, 2, 3
order by 1 desc
```

```sql
-- dbt/models/marts/mart_playlist_composition.sql
-- Question: Which artists and genres dominate each playlist?
with base as (
    select * from {{ ref('int_playlist_tracks_enriched') }}
)

select
    playlist_id,
    playlist_name,
    artist_id,
    artist_name,
    count(*)            as track_count,
    array_agg(distinct genre) filter (where genre is not null) as genres
from base
group by 1, 2, 3, 4
order by 1, 5 desc
```

---

## PostgreSQL Schema

```sql
-- Raw staging tables (loaded by Python)
create table if not exists raw_saved_tracks (
    track_id        text primary key,
    track_name      text,
    artist_id       text,
    album_id        text,
    added_at        text,
    duration_ms     int,
    explicit        boolean,
    popularity      int,
    _loaded_at      timestamp default now()
);

create table if not exists raw_saved_albums (
    album_id        text primary key,
    album_name      text,
    artist_id       text,
    added_at        text,
    total_tracks    int,
    _loaded_at      timestamp default now()
);

create table if not exists raw_playlists (
    playlist_id     text primary key,
    playlist_name   text,
    owner_id        text,
    _loaded_at      timestamp default now()
);

create table if not exists raw_playlist_tracks (
    playlist_id     text,
    track_id        text,
    added_at        text,
    position        int,
    _loaded_at      timestamp default now(),
    primary key (playlist_id, track_id)
);

create table if not exists raw_artists (
    artist_id       text primary key,
    artist_name     text,
    genres          text,   -- comma-separated, unnested in dbt
    popularity      int,
    followers       int,
    _loaded_at      timestamp default now()
);

-- Watermark table (used by incremental extractors)
create table if not exists pipeline_watermarks (
    endpoint        text primary key,
    last_extracted  timestamp not null,
    updated_at      timestamp default now()
);
```

---

## Milestones

| # | Milestone | Deliverable |
|---|-----------|-------------|
| 1 | **Infra up** | Terraform provisions EC2 + RDS + S3. SSH into EC2 confirmed. |
| 2 | **Airflow running** | Docker Compose on EC2. Both DAGs visible in UI, no import errors. |
| 3 | **Spotify auth working** | OAuth flow completes, token cached. `GET /me/tracks` returns data. |
| 4 | **Extraction + S3 landing** | All extractors run, raw JSON lands in S3 with correct prefix structure. |
| 5 | **RDS loaded** | All raw tables populated. Upsert idempotency verified by running twice. |
| 6 | **dbt staging + intermediate** | `dbt run` succeeds on staging + intermediate models. `dbt test` passes. |
| 7 | **Mart tables** | All four marts build successfully and return non-empty results. |
| 8 | **End-to-end scheduled run** | Both DAGs run automatically at midnight, Slack fires on injected failure. |
| 9 | **Audio features (stretch)** | Verify `/audio-features` access. Add extractor + staging model + mart if available. |

---

## Open Questions

- [ ] Verify `/audio-features/{id}` endpoint accessibility with new developer app
- [ ] Confirm Spotify OAuth token refresh works in headless EC2 environment (first auth requires browser; consider running initial auth locally and copying token cache to EC2)
- [ ] Decide on EC2 key pair management (AWS-generated vs. locally generated)
