# LookingForGame

Compare several Steam users' libraries and wishlists to find games they can play together. Boot.dev backend capstone.

## What to read first

- [DESIGN_DOC.md](./DESIGN_DOC.md) — architecture, data model, Steam integration constraints, open questions.
- [CONTEXT.md](./CONTEXT.md) — domain glossary (Gaggle, Member, App, Playable Set, …).
- [docs/adr/](./docs/adr/) — recorded decisions and why.

## Status

Pre-implementation. Design is being worked out via `/grill-with-docs`; no application code yet.

## Working mode

This is a learning project (boot.dev capstone). The author writes the code themselves; an AI assistant's role is to design, explain, review, and unblock — **not** to produce finished implementations unless explicitly asked for a specific piece.

## Key decisions (see ADRs for detail)

- Steam OpenID auth; Members are real records that upgrade Public-only → Verified on login (ADR-0001).
- Configurable play-together filter, co-op default (ADR-0002).
- Go backend, JSON API; frontend staged plain-JS → SPA framework (ADR-0003).

## How to run

TBD — no runnable code yet.
