-- Question: How many tracks and albums have I saved per week and per month over time?
--
-- This mart combines tracks and albums into one unified "saves" feed,
-- then buckets them by both week and month.

with tracks as (
    -- TODO: ref stg_saved_tracks, select added_at and a literal string 'track' as content_type
),

albums as (
    -- TODO: ref stg_saved_albums, select added_at and a literal string 'album' as content_type
),

combined as (
    -- TODO: UNION ALL the two CTEs above into one unified set of save events
)

-- TODO: group by week (date_trunc('week', added_at)), month (date_trunc('month', added_at)),
--   and content_type. Count saves per group.
-- Order by week descending.
