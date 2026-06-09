-- Same pattern as stg_saved_tracks: rename, cast, deduplicate.
-- Source table: raw_saved_albums

with source as (
    select * from {{ source('spotify_raw', 'raw_saved_albums') }}
),

renamed as (
    -- TODO: select and cast columns from raw_saved_albums.
    -- Cast added_at to timestamp.
    select
        -- TODO: your columns here
)

select * from renamed
