import os
import spotipy
from spotipy.oauth2 import SpotifyOAuth

# The scopes below control what personal data your app can read.
# Docs: https://developer.spotify.com/documentation/web-api/concepts/scopes
# TODO: add the three scopes you need:
#   - read the user's saved library (tracks + albums)
#   - read private playlists
#   - read collaborative playlists
SCOPES = [
    # "...",
]


def get_spotify_client() -> spotipy.Spotify:
    # TODO: return a Spotify client authenticated via SpotifyOAuth.
    #
    # SpotifyOAuth needs:
    #   client_id      — from your Spotify developer app, stored in an env var
    #   client_secret  — same
    #   redirect_uri   — must match what you registered in the developer dashboard
    #   scope          — join SCOPES above into a single space-separated string
    #   cache_path     — where Spotipy saves the token so it can auto-refresh
    #                    use "/opt/airflow/.spotify_cache" for the EC2 deployment
    #
    # Hint: SpotifyOAuth handles token refresh automatically as long as cache_path
    # is writable. The first run requires a browser redirect — do this locally,
    # then copy the cache file to EC2.
    pass
