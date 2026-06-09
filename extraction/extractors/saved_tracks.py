from datetime import datetime
from .base import BaseExtractor


class SavedTracksExtractor(BaseExtractor):
    def extract(self, after: datetime | None = None) -> dict:
        # This extractor uses WATERMARK-BASED incremental loading.
        # `after` is the last watermark timestamp — only fetch tracks added since then.
        # On the very first run, `after` will be None, so fetch everything.
        #
        # Spotify's saved tracks endpoint: GET /me/tracks
        # Spotipy method: self.client.current_user_saved_tracks(limit=50, offset=N)
        # Each item in the response has: "added_at" (ISO 8601 string) and "track" (dict)
        #
        # TODO: implement pagination.
        #   - Spotify returns max 50 items per request.
        #   - Keep incrementing the offset and calling the endpoint until response["next"] is None.
        #
        # TODO: apply the watermark filter.
        #   - If `after` is set, skip any item whose "added_at" <= after.
        #   - You can stop paginating early once items fall behind the watermark
        #     (the API returns newest-first).
        #
        # TODO: return a dict shaped like:
        #   { "items": [...], "extracted_at": "<utcnow ISO string>" }
        #   The "extracted_at" key lets you audit when the snapshot was taken.
        pass
