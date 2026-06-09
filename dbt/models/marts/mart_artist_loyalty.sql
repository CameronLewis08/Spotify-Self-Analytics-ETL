-- Question: Which artists appear most in my saved tracks, broken down by month?
-- This mart is materialized as a TABLE (rebuilt fully on each dbt run) — see dbt_project.yml.

with base as (
    -- TODO: ref int_tracks_with_artists
)

-- TODO: group by month (use date_trunc('month', added_at)) and artist.
-- Aggregate: count tracks per artist per month, and the date the first track was saved.
-- Order by month descending, then track count descending.
--
-- Useful PostgreSQL function: date_trunc('month', timestamp_col)
