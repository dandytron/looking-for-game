# Deploy to a single VPS via Docker Compose, automated with GitHub Actions

> Status: **accepted**. Resolves the open "demo host" Week-0 decision.

The live demo runs as one `docker-compose.yml` (web + worker + Postgres +
RabbitMQ) on a single small VPS (Hetzner CX-class, ~$5/mo; `restart:
unless-stopped`). Deploys are **automated with a GitHub Actions pipeline** — push
to `main` builds the images and ships them to the box — not hand-run over SSH.
TLS is terminated by Caddy (auto-renewing HTTPS) on a real domain; a free uptime
monitor (e.g. UptimeRobot) pings the link so we hear about downtime before a
visitor does; `pg_dump` runs nightly.

## Why

The goal is a **reliably clickable demo link** for an interviewer hitting it cold,
**shipped by Jul 17**, with the remaining weeks spent on Go — not on ops.

- **Cost is a tie, so it was never the deciding factor.** Always-on managed
  options also floor at ~$5/mo because a free tier won't host an always-on
  *background worker* (Render free has no workers; Railway/Fly have no real free
  tier). So the choice is about *fit*, not price.
- **No cold start anywhere.** The box never sleeps, so web, worker, Postgres, and
  RabbitMQ are all warm on the first click. Managed splits reintroduce a cold
  start at the DB layer (Neon free suspends idle compute).
- **Maximum curriculum reuse (the clincher).** Every piece maps to a boot.dev
  course already completed: Docker (Learn Docker), self-hosted RabbitMQ (Learn
  Pub/Sub in RabbitMQ and Go), Postgres (Learn SQL), the box (Learn Linux), and
  **deploy-on-push** (Learn CI/CD with GitHub Actions, Docker and Go). Only
  provisioning + Caddy TLS is genuinely new. The managed alternatives are *not*
  in the curriculum and would **bench the RabbitMQ skill** by outsourcing the
  broker to a managed service — sidelining the project's headline résumé point.
- **One place, not three vendors.** All four services talk over a private Docker
  network; no cross-vendor connection-string wiring to debug under deadline.
- **CI/CD turns the weakest objection into a strength.** Automating the deploy
  removes the "manual SSH deploy" downside *and* demonstrates the GitHub Actions
  pipeline skill — a résumé point rather than a chore.

## Considered Options

- **Managed split — Railway app + Neon Postgres + CloudAMQP RabbitMQ (~$5–15):**
  zero box to defend, free HTTPS subdomain, deploy-on-push. Rejected as the v1
  target because it benches the self-hosted-broker skill, spreads the stack
  across three dashboards, isn't in the curriculum, and bills by usage (drift
  risk). Kept as the documented portability fallback.
- **Render Blueprint (`render.yaml`), warm (~$14):** infrastructure-as-code that's
  also the deploy mechanism. Rejected on cost (~3× VPS) and same broker-benching.
- **Google Cloud Run (boot.dev's CI/CD-course target):** the curriculum's native
  deploy target, but a poor architectural fit — scale-to-zero cold starts and
  designed for stateless handlers, not always-on stateful services (RabbitMQ,
  Postgres) or a long-running worker. Rejected; its *pipeline* skill is reused,
  its *target* is not.
- **Kubernetes / AWS EC2:** in the curriculum but over-engineered (k8s) or a
  pricier, fiddlier VPS (EC2). Rejected for v1.

## Consequences

- We own sysadmin duties: OS patching, firewall (SSH key-only, ports for 80/443
  only — Postgres/RabbitMQ stay off the public internet), and restore-testing the
  backup. The ~1–2 h hardening setup is the accepted price.
- Single point of failure (one box). Acceptable for a low-traffic portfolio demo;
  the uptime monitor makes failures visible fast.
- The app stays just containers + Postgres + RabbitMQ, so the host remains
  swappable — the README documents the managed-split fallback (Railway/Render +
  Neon + CloudAMQP) and local `docker compose up`.

## Funding

The ~$5–6/mo is the price of the always-on worker + broker (free tiers don't host
always-on background workers), not a hosting markup. It does not have to come out
of pocket:

- **v1: GitHub Student Developer Pack → DigitalOcean $200 credit (1 yr)** covers a
  2 GB Droplet for over a year — the whole job-hunt window at $0 out of pocket,
  same architecture. (Or run on Hetzner CX22 ~$5/mo if not using the credit.)
- **$0 fallback: self-host on owned hardware + a free Cloudflare Tunnel**
  (`cloudflared` gives a public HTTPS URL, no static IP / port-forwarding). Caveat:
  up only while that machine and its internet are up.
- **Cost control:** VPS billing is hourly — the box can be spun up only during
  active interviewing and torn down otherwise.

## Future / better paths (deferred — post-v1 goals, not Jul 17 scope)

These are genuinely better engineering, deliberately parked so they don't eat the
deadline. Pull them in only after the demo link is live:

- **Infrastructure-as-code for the box** (Ansible or Terraform) so the server is
  reproducible instead of hand-provisioned — rebuild it from a file.
- **Registry-based, zero-downtime deploys** — push images to a container registry
  and roll them in (blue/green or `docker compose` health-gated) instead of
  build-on-box, so a deploy never shows a visitor a half-restarted stack.
- **Offsite, restore-tested backups** — ship `pg_dump` to object storage (S3) and
  actually rehearse the restore; nightly-dump-on-same-disk is not a real backup.
- **Real observability** — wire up structured logging + metrics + alerting
  (reuses Learn Logging and Observability in Go), beyond a single uptime ping.
- **Secrets management** — move off a plain `.env` on the box toward a secrets
  store once there's more than one secret that matters.
- **Re-evaluate managed/orchestrated hosting** (Kubernetes, reuses Learn
  Kubernetes) *if* the project ever needs horizontal scale or HA — it does not
  for a demo, but it's the natural "scale this up" story.
