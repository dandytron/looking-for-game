# Looking For Game

Domain glossary for LookingForGame — a tool that compares several Steam users' libraries and wishlists to surface games they can play together.

## Language

**Comparison**:
A computation over a set of Steam accounts that produces an Overlap Matrix. Exists in two forms — an ephemeral **Ad hoc Comparison** and a persistent **Gaggle**.

**Ad hoc Comparison**:
A one-off Comparison created by entering your Steam account plus N others. Nothing about the grouping is saved; it vanishes when you leave.
_Avoid_: temporary gaggle, quick gaggle (a Comparison is only a Gaggle once saved)

**Gaggle**:
The persistent, named form of a Comparison — a saved group of Members with an Owner, revisitable over time.
_Avoid_: group, party, lobby, room, session

**Member**:
A person who has joined a Gaggle by authenticating via Steam OpenID and accepting. All Members are authenticated; there is no unauthenticated Member. Membership is opt-in.
_Avoid_: friend, player, profile (a profile is the Steam-side source; a Member is our record of one); Public-only Member (superseded — see **Invite**)

**Invite**:
A pending request for a Steam account to join a Gaggle, created by an Owner (often off the back of a peek). Shown as a greyed-out placeholder column in the Matrix; contributes no Library or Wishlist data until accepted. Resolves to a Member when the invitee logs in and accepts. States: pending → accepted | declined | expired | revoked.
_Avoid_: add, request, Public-only Member

**Owner**:
The Member who created a Gaggle and administers its membership.

**Library**:
The set of Apps a Member owns.
_Avoid_: collection, games list, catalog (catalog is the global App set, not one Member's)

**Wishlist**:
The set of Apps a Member wants but does not own.

**App**:
A Steam title identified by its appid; the canonical catalog entity holding global metadata (name, categories). "Game" is the user-facing word for the same thing.
_Avoid_: title, product (when precision matters, say App)

**Overlap Matrix**:
The core computed view — a grid of App rows × account columns, each cell showing that account's relationship to the App: Owned, Wishlisted, or Absent. "Matrix" for short. Both an Ad hoc Comparison and a Gaggle render as a Matrix.
_Avoid_: table, grid, results

**Cell state**:
One account's relationship to one App within the Matrix: **Owned** (🟩), **Wishlisted** (🟨), or **Absent** (⬜, neither owned nor wishlisted).

**Playable Set**:
A filter state of the Overlap Matrix, not a separate view: the rows Owned by every account that also pass the active Play-Together Categories — "what we can play right now."
_Avoid_: matches, common games, results

**Play-Together Category**:
A Steam multiplayer classification used to decide whether an App counts as playable together — e.g. Co-op, Online Co-op, Local Co-op, Online PvP, Multi-player.

## Relationships

- A **Gaggle** has many **Members**; exactly one is the **Owner**.
- A **Gaggle** may have pending **Invites**; an **Invite** becomes a **Member** when accepted.
- A **Member** references one **Library** and one **Wishlist**, keyed by their Steam account and cached independently of Gaggle membership.
- A **Library** and a **Wishlist** each reference many **Apps**.
- A **Comparison** produces one **Overlap Matrix**; a **Gaggle** is a persisted **Comparison**.
- The **Playable Set** is the **Overlap Matrix** filtered to all-Owned rows that pass the active **Play-Together Categories**.
- Every **Member** is authenticated; a person we hold only public data on is either an account in an **Ad hoc Comparison** or a pending **Invite** — never a Member.

## Example dialogue

> **Dev:** "If a Gaggle has three Members and a fourth person is still a pending Invite, what's in the Playable Set?"
> **Domain expert:** "The Invite contributes nothing — they haven't accepted, so we hold no Library for them — and the intersection is over the three Members. When they accept, any data we cached while peeking attaches to their new Member record and joins the intersection without us re-adding them."

> **Dev:** "Is a free-to-play multiplayer App like Dota in the Playable Set if nobody 'owns' it?"
> **Domain expert:** "No — the Playable Set is strictly owned-by-all. Free-to-play discovery is handled separately, not folded into the intersection."

## Flagged ambiguities

- "profile" vs "member" vs "user" — resolved: a **Profile** is the Steam-side account we read from; a **Member** is our record of that person within a Gaggle. We avoid bare "user."
- "game" vs "app" — resolved: **App** is the canonical catalog entity (by appid). "Game" is acceptable in UI copy but means the same thing.
- "friends" — resolved: people in a Gaggle are **Members**, not "friends." (Steam *friends* — the imported friend list — is a separate, Steam-side concept.)
- "comparison" vs "gaggle" — resolved: a **Comparison** is ephemeral unless saved, at which point it becomes a **Gaggle**. Accounts in an Ad hoc Comparison are not **Members** (Membership is a property of a Gaggle).
- "Public-only Member" / "Verified Member" — superseded by the opt-in model (see [ADR-0008](./docs/adr/0008-opt-in-membership-invites.md)): every **Member** is authenticated, so the qualifier is redundant. A person we hold only public data on is an **Ad hoc Comparison** account or a pending **Invite**, never a Member. Cached Library/Wishlist data is keyed by Steam account, not by Membership.
