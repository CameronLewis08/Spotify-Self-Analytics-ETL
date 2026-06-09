from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from callbacks.slack_callback import slack_failure_callback

# default_args apply to every task in the DAG unless overridden on the task itself.
# TODO: fill in reasonable values for retries and retry_delay.
#   Think about: if the Spotify API rate-limits you, how long should Airflow wait before retrying?
DEFAULT_ARGS = {
    "owner": "de",
    "retries": ...,           # TODO: how many times should a failed task retry?
    "retry_delay": ...,       # TODO: timedelta — how long to wait between retries?
    "on_failure_callback": slack_failure_callback,
}

with DAG(
    dag_id="spotify_el",
    schedule="0 0 * * *",    # cron: daily at midnight UTC — "minute hour day month weekday"
    start_date=datetime(2026, 1, 1),
    catchup=False,            # don't backfill runs between start_date and today
    default_args=DEFAULT_ARGS,
    tags=["spotify", "extract", "load"],
) as dag:

    def extract_saved_tracks(**context):
        # TODO: read the watermark for "saved_tracks" from the pipeline_watermarks table in RDS.
        #   If no watermark exists, pass after=None (full historical pull).
        #
        # TODO: instantiate get_spotify_client() and SavedTracksExtractor(client).
        # TODO: call extractor.extract(after=watermark) to get raw data.
        # TODO: land raw data to S3 using S3Loader.land("saved_tracks", data).
        # TODO: update the pipeline_watermarks table with the new max added_at from this run.
        pass

    def extract_saved_albums(**context):
        # TODO: same watermark pattern as extract_saved_tracks, but for saved albums.
        pass

    def extract_playlists(**context):
        # TODO: no watermark needed — this is a full refresh every run.
        # Instantiate PlaylistsExtractor, call extract(), land to S3.
        pass

    def load_to_rds(**context):
        # TODO: read today's S3 files for each endpoint (saved_tracks, saved_albums, playlists).
        # TODO: parse the JSON and flatten it into rows matching the raw_* table schemas.
        # TODO: upsert into each raw_* table using RDSLoader.upsert().
        #
        # Hint: for playlists, you'll need to upsert into BOTH raw_playlists
        #   AND raw_playlist_tracks (the track list is nested inside each playlist).
        #
        # Hint: collect all unique artist_ids from this run's tracks and albums,
        #   then call ArtistMetadataExtractor and upsert into raw_artists.
        pass

    # Task definitions — one PythonOperator per callable above.
    # The three extract tasks run IN PARALLEL (no dependency between them).
    # load_to_rds runs AFTER all three extractions complete.
    t_tracks    = PythonOperator(task_id="extract_saved_tracks",  python_callable=extract_saved_tracks)
    t_albums    = PythonOperator(task_id="extract_saved_albums",  python_callable=extract_saved_albums)
    t_playlists = PythonOperator(task_id="extract_playlists",     python_callable=extract_playlists)
    t_load      = PythonOperator(task_id="load_to_rds",           python_callable=load_to_rds)

    # TODO: express the dependency: all three extract tasks must finish before load_to_rds.
    # Airflow dependency syntax: task_a >> task_b  means "task_b depends on task_a"
    # A list on the left means all must complete: [task_a, task_b] >> task_c
