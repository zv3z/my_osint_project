"""Scan engines package — parallel executor"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from .threat      import THREAT_ENGINES
from .network     import NETWORK_ENGINES
from .reputation  import REPUTATION_ENGINES
from .identity    import IDENTITY_ENGINES
from .developer   import DEV_ENGINES

ALL_ENGINES: dict = {
    **THREAT_ENGINES,
    **NETWORK_ENGINES,
    **REPUTATION_ENGINES,
    **IDENTITY_ENGINES,
    **DEV_ENGINES,
}

ENGINE_CATEGORIES = {
    "THREAT":      list(THREAT_ENGINES),
    "NETWORK":     list(NETWORK_ENGINES),
    "REPUTATION":  list(REPUTATION_ENGINES),
    "IDENTITY":    list(IDENTITY_ENGINES),
    "DEVELOPER":   list(DEV_ENGINES),
}

def run_all(target: str, ttype: str, progress_cb=None) -> dict:
    results = {}
    total = len(ALL_ENGINES)
    done  = 0
    with ThreadPoolExecutor(max_workers=14) as ex:
        futures = {ex.submit(fn, target, ttype): name
                   for name, fn in ALL_ENGINES.items()}
        for fut in as_completed(futures):
            name = futures[fut]
            try:
                results[name] = fut.result()
            except Exception as e:
                results[name] = {"error": str(e)}
            done += 1
            if progress_cb:
                progress_cb(done / total, name)
    return results
