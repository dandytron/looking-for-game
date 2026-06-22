# LookingForGame — Design Doc

> Status: in active design (grilling in progress). Sections marked **TBD** are unresolved.

## Overview

LookingForGame takes several Steam users — entered as an ephemeral **Ad hoc Comparison** or saved as a persistent **Gaggle** — and renders an **Overlap Matrix**: one row per game, one column per account, each cell showing Owned / Wishlisted / Absent. The Playable Set ("what can we play right now") and joint-wishlist exploration are filter/sort states of this single grid, not separate screens. The point is to answer "what can we all play *right now*" — and "what should we all buy" — at a glance instead of cross-referencing libraries by hand.

See [CONTEXT.md](./CONTEXT.md) for domain vocabulary and [docs/adr/](./docs/adr/) for recorded decisions.

## Decisions so far

- **Auth & membership** — Steam OpenID; every Member is a real record; Public-only → Verified upgrade in place. See [ADR-0001](./docs/adr/0001-steam-openid-auth-staged-membership.md).
- **Play-together filter** — configurable category toggles, co-op default. See [ADR-0002](./docs/adr/0002-configurable-play-together-filter.md).
- **Stack** — Go backend exposing a JSON API; frontend staged plain-JS (B) → SPA framework (C). See [ADR-0003](./docs/adr/0003-go-json-api-staged-frontend.md).
- **Datastore** — PostgreSQL. See [ADR-0004](./docs/adr/0004-postgres-datastore.md).
- **Architecture** — two Go processes (web + worker) decoupled by RabbitMQ; enrichment runs on the worker. See [ADR-0005](./docs/adr/0005-web-worker-split-rabbitmq.md).
- **Core view** — a single Overlap Matrix; ad hoc (ephemeral) vs Gaggle (persistent) modes; default sort leads with all-owned. See [ADR-0006](./docs/adr/0006-unified-overlap-matrix.md).
- **Real-time** — live Gaggle updates via SSE, fanned out from the worker through RabbitMQ. See [ADR-0007](./docs/adr/0007-sse-live-updates-broker-fanout.md).
- **Deployment** — single small VPS running all four services via Docker Compose, deploys automated with a GitHub Actions pipeline; host-portable, alternatives documented in the README. See [ADR-0010](./docs/adr/0010-deploy-vps-compose-github-actions.md).

## Steam integration constraints

These shape the whole architecture:

- **Two data classes, two retention policies.**
  - *App metadata* (appid → name, Play-Together Categories): public product facts, not personal data. Cached globally, effectively no expiry.
  - *Member library/wishlist* (SteamID ↔ owned/wished Apps): personal data. TTL'd, deletable per Member.
- **`appdetails` is the bottleneck.** Category metadata comes from Steam's unofficial store `appdetails` endpoint, rate-limited to ~200 req / 5 min, no key. Mitigated because metadata is global and cached once per App — the limit only bites during cold backfill. A background enrichment queue (RabbitMQ) drains unknown appids at a rate-respecting pace.
- **Keyed Web API** (`GetOwnedGames`, `GetFriendList`, `ResolveVanityURL`, wishlist): free key, 100k calls/day — generous.
- **Two-tier privacy — the developer key sees *public data only*.** This corrects an earlier assumption. The Web API key is *our* credential, not the Member's; it returns a profile's data strictly per that profile's privacy settings. A Friends-Only or Private Library/Wishlist reads as **empty to the key** (live-verified: `xcielx`, `skittlesohenry` returned nothing). Steam OpenID login proves *identity* (SteamID64) but grants **no** data access — it does not unlock private data. The *only* way to read a Member's private Library/Wishlist is **that Member's own short-lived Steam web-session `access_token`** (`aud: web:store`, ~24h expiry, IP-stamped, no third-party refresh path), passed to `IWishlistService`/`GetOwnedGames` in place of the key. See **Private-profile resilience** below and `tests/steam_probe.sh`.

### Private-profile resilience

**A Member whose Library and/or Wishlist isn't public must not break the comparison.** The Overlap Matrix is computed over whatever data is readable, not gated on every Member being fully public.

- **Degrade, don't error.** A Member with no readable Library/Wishlist still renders as a present column, flagged **"private — not shared,"** with a one-click prompt to fix it (make profile public, *or* opt in — below). The Matrix for the remaining Members renders normally.
- **Distinguish three cell states, not two.** Owned / Wishlisted / Absent assumes we *know*. A private Member's cells are a fourth state — **Unknown** — and must render differently from a confirmed *Absent*, so the grid never implies a fact we don't have.
- **v1 inclusion path — make it public.** The blessed, zero-secret path and the **only** one v1 supports: a one-time Steam privacy toggle (Profile + Game Details; Wishlist follows — *pending confirmation*, see investigation note). Thereafter the dev key reads the Member forever. Onboarding hands the Member the exact toggles to flip, detected from the profile XML `privacyState`, rather than a misleading "your wishlist is empty."
- **Propagation (unverified).** We *attempted* to measure how long the keyed Web API serves a stale view after a privacy change, but the experiment was invalid — the test account's Game Details stayed **Public** the whole time, so there was no restricted state to propagate. We therefore have **no measured lag**. Out of caution the add-Member flow should still treat a just-made-public Member that reads empty with a "give it a moment, then retry" state rather than an immediate-empty = failure — but treat that as defensive design, not a known Steam behavior.

**Deferred — opt-in private import (token path).** Reading a private Member's data *without* making the profile public is technically proven (the Member's own Steam web-session `access_token` returned the full 736-item wishlist / 908-game library the dev key could not), but it's **out of v1 scope**: the token can't be obtained via OpenID, expires ~24h with no third-party refresh, is IP-stamped, and is a full-account bearer credential we'd rather not custody. Parked as future work; see [Future work](#future-work--explicitly-deferred).

**Open question (do not silently resolve):** how does an **Unknown** Member affect the all-owned **Playable Set**? Even in public-only v1 a Member can simply be private. Excluding them ("owned by all *Members with known data*") keeps the app useful but can surface a game as playable-by-all when the private Member may not own it; treating Unknown as a blocker is honest but lets one private Member empty the Playable Set entirely. Needs a deliberate call (and likely its own ADR) — candidate for the next grilling pass.

## Data model (sketch)

```
users          (steam_id PK, display_name, avatar, verified, last_login)
gaggles        (id PK, name, created_by -> users, created_at)
gaggle_members (gaggle_id -> gaggles, user_id -> users, role, joined_at)
libraries      (user_id -> users, app_id, playtime, fetched_at)   -- TTL'd
wishlists      (user_id -> users, app_id, added_at, fetched_at)    -- TTL'd
apps           (app_id PK, name, categories, header_image_url, fetched_at)  -- global, no-expiry
```

Library/Wishlist hang off `user_id`, not the Gaggle, so a Member's data is fetched once and reused across every Gaggle they're in.

## Access & joining (revisable default)

- Each Gaggle has an **unguessable URL slug** — unlisted, not enumerable or indexed.
- **Anyone with the link can view** the Matrix read-only.
- **Join with Steam** (OpenID) to become a Verified Member and contribute your Library/Wishlist.
- The Owner can also add **Public-only Members** by pasted profile (vanity URL or SteamID64); this coexists with self-serve join.
- Rationale: the displayed data is low-sensitivity ("which games I own/want"), already world-readable for public Steam profiles, so gating views behind login adds friction for little privacy gain. Easy to tighten to members-only later if needed.

## Freshness model

- **App metadata** — effectively immutable; cached with no expiry. A missing App is filled asynchronously via the enrichment queue and shown as "pending" until the worker writes it.
- **Member Library/Wishlist** — **stale-while-revalidate** with a **24h TTL**. On Gaggle view, the cached Playable Set is served instantly; if a Member's data is older than the TTL, a background refresh job is published to the broker so it's fresh next time. The UI shows a "last synced" timestamp and a manual Refresh button.
- **Synchronous exceptions** — first time a Member is added (no cached data to serve; show a loading state) and explicit manual refresh.
- **Configurability** — the TTL lives as a single named constant (e.g. `LibraryTTL`), overridable by environment variable so it can be tuned per environment without recompiling.

## Game art

Matrix rows display Steam's own artwork, loaded directly from Steam's CDN — no re-hosting. The `appdetails` enrichment call returns each App's `header_image` URL, which is stored on the `apps` row; the frontend points `<img>` at it. (Image URLs are also derivable from the appid by convention as a fallback.) Our own S3/CloudFront is reserved solely for *generated* assets (OG share cards — see future work), not for proxying Steam art.

## Real-time updates

Gaggle pages update live via **Server-Sent Events** — the group typically views a Gaggle simultaneously while deciding what to play, so Member joins and data refreshes ripple to everyone watching. SSE connections are held by the web process; worker-side changes reach them through a **RabbitMQ fanout exchange** (the worker publishes a thin "gaggle G changed" event; web processes consume and push to relevant SSE clients). Events carry IDs only — the web process re-reads authoritative state from Postgres and pushes the updated Matrix. See [ADR-0007](./docs/adr/0007-sse-live-updates-broker-fanout.md). This makes the broker's role twofold: enrichment **work queue** + change **event fan-out**.

## Free-to-play handling

F2P multiplayer Apps are **not** folded into the Playable Set (which is strictly owned-by-all). Instead, a discovery nudge — a widget/tooltip ("Nothing catching your interest? Check out Free-to-play titles on Steam") — points users outward. Known trade-off: a generic link is cheap but loses the personalized "you could all play Dota right now" insight a true F2P carve-out would surface. Revisit post-v1.

## Future work / explicitly deferred

- **Player-count-aware matching** — important to the user, but deferred until the core is built. Steam exposes no reliable structured max-player field (data lives in free-text requirements or not at all), so this is best-effort and needs its own design pass.
- **Member self-login (v2)** — schema supports many Verified Members; the login UX for non-Owner Members is a later increment.
- **Opt-in private import via session token (post-v1)** — let a Member who won't make their profile public contribute anyway by supplying their own Steam web-session `access_token` for a one-shot snapshot import (store the games, discard the token). Proven feasible this session; deferred for the operational cost (24h expiry, no refresh, IP-stamping, credential-custody risk). Wants its own ADR before any build.
- **F2P personalized carve-out** — see above.
- **OG share cards (stretch)** — generated preview images for shared Gaggle links (member avatars + playable count), stored in S3 and served via CloudFront. The intended, non-contrived use of the file-server/CDN skill; off the critical path.
- **Deploy hardening (post-v1)** — better-engineering upgrades to the v1 VPS deploy, parked so they don't eat the Jul 17 deadline: infrastructure-as-code for the box (Ansible/Terraform), registry-based zero-downtime deploys, offsite restore-tested backups, real observability (structured logging + metrics + alerting), and secrets management. Pull in only after the demo link is live. See the "Future / better paths" section of [ADR-0010](./docs/adr/0010-deploy-vps-compose-github-actions.md).

## Deployment

- **Live demo:** a single small VPS (~$5/mo) running all four services — web, worker, Postgres, RabbitMQ — via one `docker-compose.yml`, with `restart: unless-stopped` and a nightly `pg_dump`. Deploys are automated with a **GitHub Actions pipeline** (push to `main` → build + ship), TLS via Caddy, uptime watched by a free monitor. Cheapest always-on option for a four-service stack (no per-service charges, no free-tier cold starts), and the path that reuses the most boot.dev coursework (Docker, RabbitMQ/pub-sub, Postgres, Linux, CI/CD). Full reasoning and the rejected alternatives in [ADR-0010](./docs/adr/0010-deploy-vps-compose-github-actions.md).
- **Why not a free tier:** four always-on services exceed typical free tiers or get slept; a 50s cold start reads as "broken" to a visiting interviewer. The hosting cost is the accepted price of the RabbitMQ/worker architecture chosen for résumé value.
- **Portability:** the app is just containers + Postgres + RabbitMQ, so the host is swappable. The **README will carry a Self-hosting section** documenting local `docker compose up` plus alternative targets (VPS, Fly.io, Render) and a $0 free-tier split (Neon + CloudAMQP + Fly/Render).
- **Demo UX:** keep the site public (no password gate); seed a public demo Gaggle behind a "Try a sample" button so a visitor without Steam friends still sees a populated Matrix in one click.

## Open branches

Most architecturally significant decisions are resolved (ADRs 0001–0007 + the decisions above). The Steam data endpoints are now live-verified — wishlist via `IWishlistService/GetWishlist`, library via keyed `GetOwnedGames`, vanity via `ResolveVanityURL`, metadata via `appdetails` (see [ADR-0009](./docs/adr/0009-steam-data-endpoints-verified.md) and `tests/steam_probe.sh`).

**Reopened by the privacy findings (this session):**
- The dev-key-sees-public-only correction invalidates the old "OpenID unlocks private data" premise in [ADR-0001](./docs/adr/0001-steam-openid-auth-staged-membership.md) — that ADR's rationale needs an amendment (the upgrade-in-place membership mechanic still stands; the *why* does not).
- **v1 scope is now public-profile-only** (private import deferred — see above). The **Unknown** cell state and its effect on the all-owned Playable Set still want a deliberate decision + ADR.

Otherwise remaining work is implementation-level: schema migrations, testing strategy, and CI.
