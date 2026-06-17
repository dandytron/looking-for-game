# tests/ — Week-0 feasibility spike

Proves we can actually pull the Steam data LookingForGame depends on **before**
writing any app code. Pure `curl` + `grep`/`sed`; no Go, no deps.

## Run

```sh
./steam_probe.sh dandytron                      # keyless probes
STEAM_API_KEY=xxxxxxxx ./steam_probe.sh dandytron   # also runs keyed probes
```

Accepts a vanity name (`dandytron`) or a raw SteamID64. Raw API responses are
dumped to `out/` (gitignored) for inspection.

## What each probe proves

| # | Probe | Endpoint | Needs key? |
|---|-------|----------|------------|
| 1 | Resolve vanity → SteamID64 | public `?xml=1` profile (keyless) + `ISteamUser/ResolveVanityURL` (keyed, production path) | no / optional |
| 2 | Owned games (Library) | community `games?xml=1` (keyless) + `IPlayerService/GetOwnedGames` (keyed) | **yes, in practice** |
| 3 | Wishlist | `IWishlistService/GetWishlist/v1` | **no** |
| 4 | Enrichment | `store/api/appdetails?filters=basic,categories` | no |

Required probes = wishlist + appdetails (script exits non-zero if they fail).
Owned-games keyless `0` is a **WARN**, not a failure.

## Current finding (keyless, profile `dandytron`, public)

- ✅ **Wishlist works keyless** — HTTP 200, 736 items, shape `{appid, priority,
  date_added}`. Closes the open wishlist-endpoint question with live data; the
  legacy `store/wishlistdata` endpoint stays dead.
- ✅ **Enrichment works keyless** — `appdetails` returns name + categories, which
  feed the Play-Together filter.
- ⚠️ **Owned games returns 0 keyless** despite a public profile — Steam gates the
  games list behind a *separate* "game details" privacy toggle (and the scrape
  path is unreliable regardless). **The Library column is the real reason we need
  the keyed `GetOwnedGames` call.** Re-run with `STEAM_API_KEY` set to confirm it
  flips to PASS.

## Not in scope

Throwaway spike — not the Go Steam client (that's P1). Delete or keep as a
smoke-test once the real client exists.
