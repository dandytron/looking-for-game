# Unified Overlap Matrix as the core view

The core view is a single **Overlap Matrix** — App rows × account columns, each cell showing Owned / Wishlisted / Absent — rather than separate "what can we play" and "joint wishlist" screens. The Playable Set and wishlist exploration are filter/sort states of this one grid, not distinct features.

A Matrix is produced in two modes: an **Ad hoc Comparison** (your account + N others; nothing about the grouping is persisted) and a **Gaggle** (a saved, named Comparison with Members and an Owner).

Default row ordering, with the Play-Together filter applied throughout:
1. **All-owned** — every account owns it (playable right now). Leads.
2. **Complete hit** — every account wishlists it.
3. **Owned by most** — descending owner count, wishers shown.
4. **Most wishlisted** — descending wisher count, owned by none.

Recorded because it shapes the main query and the API response contract, and because the ad hoc/persistent split determines what is written to the database.

## Consequences

- An Ad hoc Comparison persists nothing about the grouping, but still populates the per-account Library/Wishlist cache (keyed by SteamID) and the global App-metadata cache.
- Only a Gaggle creates membership and Owner records.
- The API returns the Matrix as a single structure (rows + per-account cell states + tallies); the frontend renders it directly.
