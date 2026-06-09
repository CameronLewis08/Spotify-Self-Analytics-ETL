from datetime import datetime
from .base import BaseExtractor


class PlaylistsExtractor(BaseExtractor):
    def extract(self) -> dict:
        # This extractor uses FULL REFRESH loading (no watermark).
        # Playlists can have tracks removed, so you can't safely use a watermark —
        # you must always pull the full current state.
        #
        # Step 1 — fetch all playlists:
        #   Spotipy: self.client.current_user_playlists(limit=50)
        #   Paginate using self.client.next(response) until response["next"] is None.
        #
        # Step 2 — for each playlist, fetch its full track list:
        #   Spotipy: self.client.playlist_tracks(playlist_id, limit=100)
        #   Paginate the same way. Attach the tracks to the playlist dict
        #   under a key like "tracks_full" so the loader can access them.
        #
        # TODO: return { "playlists": [...], "extracted_at": "..." }
        pass
