# LookingForGame — Build Schedule (best-guess)

> Target: **Fri 2026-07-17** (mid-July). Written 2026-06-15.
> Cadence assumed: **1–3 h/weekday, 2–6 h/weekend day** → ~9–27 h/week, **~18 h mid**, ~**70–90 h** total.
> Companion to [build-plan.html](./build-plan.html) (the phase/architecture diagram) and the ADRs.

## The honest framing

Full scope (all six phases) is ~80–95 h of *smooth-path* work — and you're learning Go while meeting RabbitMQ, Steam OpenID, and SSE for the first time. So this plan has a **cut line**, not just an order:

- **Ships by Jul 17 (v1):** Phase 0 → 3 **+ deploy**. This is the impressive core — a deployed app with the broker/worker story *and* real auth *and* the Matrix.
- **Stretch (only if ahead):** Phase 4 (live SSE), Phase 5 polish (stale-while-revalidate, demo seed, README self-hosting).

If you protect one thing, protect **finishing P1 by end of Week 2** — that's the first end-to-end slice and the morale checkpoint. If P1 slips, cut scope, don't cut the deadline.

## Week 0 — before you write app code (do this now, ~2 h)

These are blockers; sort them before Week 1 needs them.

- [ ] **Steam Web API key** — register one (free). Blocks P1.
- [ ] **Two test Steam accounts** with public libraries (yours + a friend's SteamID64) to develop against.
- [x] **Resolve the wishlist-endpoint question** — DONE: `IWishlistService/GetWishlist/v1` (legacy store endpoint is deprecated), live-verified keyless against a real profile via `tests/steam_probe.sh`. See [ADR-0009](./adr/0009-steam-data-endpoints-verified.md).
- [x] **Decide the host** — DONE: single VPS via Docker Compose, auto-deployed with GitHub Actions ([ADR-0010](./adr/0010-deploy-vps-compose-github-actions.md)). _Still to do: actually provision the box before deploy week._

## Calendar

| Week | Dates | Phase focus | Milestone (done when) |
|------|-------|-------------|-----------------------|
| 1 | Mon Jun 15 – Sun Jun 21 | P0 Foundation + start P1 | `docker compose up` all green; CI passes; Steam client fetching a real library |
| 2 | Mon Jun 22 – Sun Jun 28 | Finish P1 (tracer bullet) | Two SteamIDs → owned/absent Matrix in the browser, served from cache |
| 3 | Mon Jun 29 – Sun Jul 5 | P2 Enrichment + Playable Set | Cold App set drains through the broker without tripping Steam's limit; Playable Set appears |
| 4 | Mon Jul 6 – Sun Jul 12 | P3 Auth, Gaggles, Invites, Wishlists | Two real people log in, land in one Gaggle by link, see each other's libraries + wishlists |
| 5 | Mon Jul 13 – Fri Jul 17 | **Deploy** + buffer | Cold visitor clicks the live link and sees a Matrix |

## Week-by-week

### Week 1 — Foundation + first Steam call (P0 → P1 start)
- Go project layout: two binaries (`web`, `worker`), shared packages.
- `docker-compose.yml`: Postgres + RabbitMQ + web + worker all boot.
- First migration (apps, libraries, wishlists, users, gaggles, gaggle_members, invites).
- CI: build both binaries, run migrations against throwaway Postgres.
- Begin the Steam Web API client: `GetOwnedGames` for one SteamID, printed to stdout.
- **Risk:** Go + Docker + migrations setup eats more than expected. If it does, push the Steam client to Week 2 and keep the slice intact.

### Week 2 — Ad hoc Matrix, end to end (P1)
- Fetch two libraries, write to the SteamID-keyed cache (no Member/Gaggle yet).
- Compute the Matrix (Owned / Absent only) and return it as one JSON structure.
- Minimal plain-JS page renders the grid. No styling polish.
- **Milestone:** the morale checkpoint — something real works. Demo it to yourself.

### Week 3 — Enrichment + Playable Set (P2, the headline)
- Web publishes `enrich appid` for any uncached App.
- Worker consumes, calls `appdetails` behind a **token bucket**, writes categories.
- Apply the Play-Together filter (co-op default) → Playable Set.
- UI shows `pending` rows that fill as the worker drains.
- **Risk (highest):** RabbitMQ connection/ack/redelivery semantics + rate-limit tuning. Budget the whole week; this is the part most likely to overrun. Fallback if stuck: in-process queue first to prove the flow, swap to RabbitMQ once it works (the broker is the résumé point, so don't *ship* without it — but it's fine to learn the logic in-process first).

### Week 4 — Auth, Gaggles, Invites (P3)
- Steam OpenID login → Member; session cookie.
- Save a Comparison as a named Gaggle (Owner + members; unguessable slug).
- Invite flow: pending Invite → Member on accept (per ADR-0008); pending column greyed out.
- Add Wishlists (the Wishlisted cell state) using the endpoint chosen in Week 0.
- Per-SteamID delete path; cached peek-data attaches on accept.
- **Risk:** OpenID round-trip + session handling is fiddly. If Invites overrun, ship "Owner + self-join by link" and defer the full Invite state machine.

### Week 5 (partial) — Deploy + buffer (subset of P5)
- Deploy all four services to the VPS via Compose (`restart: unless-stopped`, nightly `pg_dump`), with a GitHub Actions pipeline (push to `main` → build + ship), Caddy TLS, and an uptime monitor. See [ADR-0010](./adr/0010-deploy-vps-compose-github-actions.md).
- Smoke-test the live link cold.
- Remaining days are **buffer** — they will get used. If you're somehow ahead, pull in SSE (P4) or the demo-seed Gaggle.

## Cut order if you fall behind (drop from the bottom up)

1. OG share cards — already deferred.
2. P5 stale-while-revalidate + demo seed + README self-hosting.
3. P4 SSE live updates (reload-to-refresh is an acceptable v1).
4. Full Invite state machine → "Owner + self-join by link" instead.
5. Wishlist column → libraries-only Matrix.

Everything above the line you do **not** cut: P0–P2 (the broker story) and basic auth + a deployed link. That's the artifact.

## Assumptions / where this is wrong

- Estimates assume the design holds; a domain rethink mid-build resets the clock.
- Go learning curve is the biggest unknown — if it's your first real Go project, shift everything one phase later and let P4/P5 fall off.
- "Mid-July = Jul 17." If it's hard, the cut line is what saves the date.
