-- Joins playlist membership (stg_playlist_tracks) to playlist metadata and track/artist info.
-- The mart_playlist_composition model builds directly on top of this.

with playlist_tracks as (
    -- TODO: ref stg_playlist_tracks
),

playlists as (
    -- TODO: ref stg_playlists
),

tracks_with_artists as (
    -- TODO: ref int_tracks_with_artists
)

-- TODO: join all three CTEs together.
-- playlist_tracks is your base — every row is one track in one playlist.
-- Join playlists to get playlist_name.
-- Join tracks_with_artists to get track_name, artist_id, artist_name, genres, popularity.
-- Select: playlist_id, playlist_name, track_id, position,
--         track_name, artist_id, artist_name, genres, popularity
