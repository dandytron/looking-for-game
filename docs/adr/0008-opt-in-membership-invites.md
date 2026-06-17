# Opt-in Gaggle membership via Invites

Gaggle membership is **opt-in**: a person becomes a Member only by authenticating via Steam OpenID and accepting. Pasting a profile no longer enrolls anyone — it either feeds an ephemeral **Ad hoc Comparison** (reading public data, no membership) or creates a pending **Invite** the person must accept. This supersedes the "Public-only Member added by pasted profile" part of [ADR-0001](./0001-steam-openid-auth-staged-membership.md).

Pending Invites appear as a greyed-out placeholder column in the Matrix and contribute no Library/Wishlist data until accepted, at which point any data cached while peeking attaches in place (the upgrade-in-place mechanic from ADR-0001, repurposed).

## Why

Enrolling a person into a named, persistent group without their consent is the wrong default. Reading already-public Steam data to show a one-off comparison is fine — Steam itself enforces the privacy half (private libraries are readable only by the authenticated owner). So "opt-in" is specifically about **consent to be a Member of a named group**, not about data access.

## Consequences

- An Owner can no longer single-handedly populate a Gaggle by pasting friends; each Member logs in to join. More friction than ADR-0001's v1 — accepted on purpose.
- A Gaggle Matrix is therefore all-authenticated Members (no half-readable Public-only columns muddying it).
- New domain entity: **Invite**, with states `pending → accepted | declined | expired | revoked`.
- Cached Library/Wishlist data is keyed by **Steam account**, not by Membership (see the data-subject decision); the per-subject delete path operates on SteamID and covers ad hoc peeks, Invites, and Members uniformly.
