from datetime import datetime
from .base import BaseExtractor


class ArtistMetadataExtractor(BaseExtractor):
    # Spotify's /artists endpoint accepts up to 50 IDs per request (batch lookup).
    BATCH_SIZE = 50

    def extract(self, artist_ids: list[str]) -> dict:
        # This extractor is called AFTER saved_tracks and saved_albums are loaded,
        # so you can collect all unique artist_ids from those tables first.
        #
        # Spotipy: self.client.artists(list_of_up_to_50_ids)
        # Returns: { "artists": [...] } where each artist has id, name, genres, popularity, followers.
        #
        # TODO: split artist_ids into batches of BATCH_SIZE and call self.client.artists()
        #       for each batch. Collect all results into a single list.
        #
        # TODO: return { "artists": [...], "extracted_at": "..." }
        pass
