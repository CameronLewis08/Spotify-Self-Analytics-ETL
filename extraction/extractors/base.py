from abc import ABC, abstractmethod
from typing import Any


class BaseExtractor(ABC):
    # TODO: write an __init__ that accepts a Spotipy client and stores it as self.client

    @abstractmethod
    def extract(self, **kwargs) -> dict[str, Any]:
        # Every extractor must implement this method.
        # It should return the raw API response as a plain Python dict
        # (not yet transformed — that happens in dbt).
        ...
