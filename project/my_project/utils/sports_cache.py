
import time
from threading import Lock

_cache_lock = Lock()
_cache_data = None
_cache_expires_at = 0.0


def get_cached_sports(loader, enabled=True, ttl=45):
    global _cache_data, _cache_expires_at

    if not enabled:
        return loader(), "BYPASS"

    with _cache_lock:
        now = time.monotonic()

        # Дані є, і TTL ще не закінчився
        if _cache_data is not None and now < _cache_expires_at:
            return _cache_data, "HIT"

        # Даних немає або TTL закінчився
        data = loader()

        _cache_data = data
        _cache_expires_at = time.monotonic() + ttl

        return data, "MISS"


def invalidate_sports_cache():
    global _cache_data, _cache_expires_at

    with _cache_lock:
        _cache_data = None
        _cache_expires_at = 0.0
