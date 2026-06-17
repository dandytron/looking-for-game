# Steam data endpoints, verified against a live profile

> Status: **accepted**. Closes the open wishlist-endpoint branch from the
> DESIGN_DOC with empirical results, not just docs.

Before writing app code we ran a keyless+keyed feasibility spike
(`tests/steam_probe.sh`) against a real public profile
(`dandytron` / SteamID64 `76561198000323336`). The endpoints below are the ones
the product will use, chosen from live behaviour.

## Decisions

- **Wishlist → `IWishlistService/GetWishlist/v1`** (keyed Web API host).
  Returns `{appid, priority, date_added}` per item — **no name/metadata**. Live:
  HTTP 200, 736 items, **keyless**. The thin shape is a fit: bare appids flow
  into the same enrichment queue as Library appids. The legacy
  `store.steampowered.com/.../wishlistdata` endpoint is deprecated and not used.
- **Library → `IPlayerService/GetOwnedGames/v1`** (`include_appinfo=1`),
  **requires the Web API key**. Live: 924 games keyed; the keyless community
  `games?xml=1` scrape returned **0** for the same public profile (Steam gates
  the games list behind a separate "game details" toggle and the scrape path is
  unreliable). This is *the* reason the key is a Week-0 blocker.
- **Vanity → SteamID64 → `ISteamUser/ResolveVanityURL/v1`** (keyed) as the
  production path; the keyless `?xml=1` profile view agreed and is a usable
  fallback. Inputs may be a vanity name or a raw SteamID64.
- **App metadata → `store/api/appdetails`** (`filters=basic,categories`),
  keyless. Supplies the Play-Together categories the filter needs.

## Why it matters

- The wishlist column carries **no key dependency** — it can be built and demoed
  before any auth exists.
- The Library column's key requirement, confirmed live, sharpens P1: the first
  real Matrix needs the key wired in, the wishlist column does not.

## Consequences / known fragilities

- `IWishlistService` and `appdetails` are **undocumented** Steam endpoints; Valve
  can change them without notice (they already killed `wishlistdata`). Treat both
  as best-effort with defensive parsing.
- `appdetails` is rate-limited (~200 req / 5 min, no key) — already the reason
  for the enrichment queue (see [ADR-0005](./0005-web-worker-split-rabbitmq.md)).
- Re-verify with `tests/steam_probe.sh` if behaviour drifts; raw dumps land in
  `tests/out/`.
