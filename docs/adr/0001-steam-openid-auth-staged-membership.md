# Steam OpenID auth with staged membership

We authenticate Members via Steam OpenID 2.0 (free, no Valve relationship beyond a Web API key) rather than a paste-only model, because logging in is the only way to read a Member's *private* Library/Wishlist and to import their Steam friends list — the features that make the product feel effortless.

Every Member is modelled as a real account record from day one, including friends added by pasted profile reference. Such a Member starts **Public-only** (we read only their public Steam data) and upgrades to **Verified** in place on first login — no schema migration, no re-adding.

## Considered Options

- **Paste-only (no auth):** simplest, but silently breaks on private profiles, can't read wishlists for them, and can't import friend lists. Rejected.
- **Owner-only auth:** one logged-in Owner per Gaggle; friends always read as public. Rejected as the v1 *model* (we model many authenticated Members up front) but adopted as the v1 *build stage*.

## Consequences

- Gaggle membership requires real account + role records, and personal data (the SteamID↔Library/Wishlist association) carries data-retention duties: per-Member delete path and TTL'd library/wishlist data.
- v1 may ship with only the Owner actually logging in; additional Members logging in is a later increment the schema already supports.
