-- Intermediate models join or restructure staging models to prepare data for marts.
-- They are materialized as `ephemeral` (inline CTEs, no table created) — see dbt_project.yml.
-- {{ ref() }} creates a dependency on another model, so dbt builds in the right order.

with tracks as (
    -- TODO: reference stg_saved_tracks using {{ ref() }}
),

artists as (
    -- TODO: reference stg_artists using {{ ref() }}
)

-- TODO: join tracks to artists on artist_id.
-- Use a LEFT JOIN — some tracks may have artist_ids not yet in raw_artists
-- if the artist enrichment step missed them.
-- Select: track_id, track_name, added_at, duration_ms, popularity,
--         artist_id, artist_name, genres
