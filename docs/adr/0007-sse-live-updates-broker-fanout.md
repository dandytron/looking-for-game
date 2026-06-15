# Live Gaggle updates via SSE, fanned out through RabbitMQ

Gaggle pages update **live** (not reload-only): when a Member joins or a Member's data refreshes, the change ripples to everyone currently viewing. This is core to v1 — the primary use case is a group deciding what to play *together, simultaneously* (often while on Discord), so concurrent viewing is the norm.

The browser subscribes via **Server-Sent Events** (one-way server→client; lighter than WebSockets and sufficient for "something changed" pushes). SSE connections are held by the web process, but the work happens on the worker process, so change-events cross processes via a **RabbitMQ fanout exchange**: the worker publishes a thin "gaggle G changed" event; every web process consumes it and pushes to the SSE clients watching G.

This extends the broker's role from work dispatch (ADR-0005) to **work queue + event fan-out**, and supersedes the earlier "real-time deferred" stance.

## Considered Options

- **Postgres LISTEN/NOTIFY:** no new component, but Postgres-specific and a second messaging mechanism alongside the broker. Viable fallback; rejected for narrative and uniformity since the broker is already central.
- **Web polls the DB:** laggy and wasteful. Rejected.

## Consequences

- Event payloads are thin (IDs only: "gaggle G / app N changed"); the web process re-reads authoritative state from Postgres and pushes the updated Matrix (or a diff) down SSE. State is never shipped through the event.
- Fan-out works correctly across multiple web instances (each consumes the event), so horizontal scaling of the web tier needs no rework.
- Requires a separate fanout exchange distinct from the enrichment work queue.
