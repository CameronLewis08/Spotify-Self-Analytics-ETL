-- Each row is one track in one playlist.
-- The primary key is (playlist_id, track_id) — a track can appear in multiple playlists.

with source as (
    select * from {{ source('spotify_raw', 'raw_playlist_tracks') }}
),

renamed as (
    -- TODO: select playlist_id, track_id, added_at (cast to timestamp), position, _loaded_at
    select
        -- TODO: your columns here
)

select * from renamed
