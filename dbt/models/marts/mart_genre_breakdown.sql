-- Question: What are the top genres in my saved tracks library by track count?
--
-- The genres column is a comma-separated string (e.g. "pop,indie pop,art pop").
-- You need to split it into one row per genre before you can count.
--
-- Key PostgreSQL functions:
--   string_to_array(genres, ',')  → converts "pop,indie pop" to ARRAY['pop','indie pop']
--   unnest(array)                 → expands an array into one row per element
--   trim(text)                    → removes leading/trailing whitespace from each genre

with exploded as (
    -- TODO: ref int_tracks_with_artists
    -- TODO: use unnest(string_to_array(genres, ',')) to expand genres into one row per genre.
    --   Filter out rows where genres is null before unnesting.
    --   Carry through track_id and added_at so you can aggregate below.
)

-- TODO: group by genre (trimmed), count tracks, and find the earliest added_at.
-- Order by track_count descending.
