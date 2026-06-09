-- Artist metadata. genres is stored as a comma-separated string in raw —
-- it gets unnested later in the mart models using string_to_array() + unnest().

with source as (
    select * from {{ source('spotify_raw', 'raw_artists') }}
),

renamed as (
    -- TODO: select artist_id, artist_name, genres (keep as text), popularity, followers, _loaded_at
    select
        -- TODO: your columns here
)

select * from renamed
