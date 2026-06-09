-- Question: Which artists and genres dominate each of my playlists?
--
-- Like mart_genre_breakdown, genres need to be unnested per row.
-- Use a LATERAL join (or a subquery with unnest) to expand genres inline.

with base as (
    -- TODO: ref int_playlist_tracks_enriched
)

-- TODO: group by playlist_id, playlist_name, artist_id, artist_name.
-- Aggregate:
--   - count of tracks per artist per playlist
--   - array of distinct genres for that artist in that playlist
--     Hint: array_agg(distinct trim(g)) filter (where g is not null)
--           where g comes from a lateral unnest of the genres string
--
-- Hint for the lateral unnest pattern:
--   FROM base, lateral unnest(string_to_array(genres, ',')) as g
--
-- Order by playlist_id, then track_count descending.
