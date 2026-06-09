-- Staging model for playlist metadata (not the tracks inside them — that's stg_playlist_tracks).

with source as (
    select * from {{ source('spotify_raw', 'raw_playlists') }}
),

renamed as (
    -- TODO: select playlist_id, playlist_name, owner_id, _loaded_at
    select
        -- TODO: your columns here
)

select * from renamed
