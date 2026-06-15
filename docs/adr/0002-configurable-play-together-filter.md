# Configurable play-together filter, co-op by default

The Playable Set is computed by a configurable filter over Steam's Play-Together Categories (Co-op, Online Co-op, Local Co-op, Online PvP, Multi-player, …) rather than a single hard-coded notion of "multiplayer." The engine supports independent toggles from the start; the UI ships defaulting to **Co-op**, with toggles to widen (e.g. include PvP, include local-only).

This is recorded because a reader seeing the toggle machinery might assume a simpler "multiplayer: yes/no" filter would do — but groups genuinely want PvP-without-co-op, online-without-local, etc., so the category granularity is deliberate.

## Considered Options

- **A — Any multiplayer flag:** broadest, simplest, but lumps PvP-only and async "multiplayer" in with real co-op. Rejected as the default behaviour.
- **B — Co-op only:** matches common intent but too rigid as the *only* mode. Adopted as the default, not the whole engine.
- **C — Configurable toggles:** chosen. Built as the engine; defaults to B.

## Consequences

- Requires fetching and caching per-App category metadata from Steam's `appdetails` (the rate-limited, unofficial endpoint), protected by a global App-metadata cache.
- Player-count-aware filtering is explicitly **out of scope for v1** (Steam exposes no reliable structured max-player field); see DESIGN_DOC future work.
