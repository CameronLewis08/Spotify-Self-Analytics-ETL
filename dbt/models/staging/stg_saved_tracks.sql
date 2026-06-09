-- Staging models are views over a single source table.
-- Their only job: rename columns to your conventions, cast types, and deduplicate.
-- No joins, no business logic — that belongs in intermediate models.

with source as (
    -- {{ source() }} tells dbt where the raw data lives (defined in sources.yml).
    -- This also enables dbt's source freshness checks.
    select * from {{ source('spotify_raw', 'raw_saved_tracks') }}
),

renamed as (
    -- TODO: select all columns you want downstream models to use.
    -- Cast added_at from text to timestamp.
    -- Keep _loaded_at so you can audit when each row arrived.
    select
        -- TODO: your columns here
)

select * from renamed
