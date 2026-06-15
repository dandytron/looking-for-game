# Go backend, JSON API, staged frontend (B → C)

The backend is Go, exposing a **JSON API** (not server-rendered HTML). The frontend is staged: a plain-JavaScript client now (option B), evolving to a JS-framework SPA later (option C, e.g. React/Svelte) without backend changes.

Designing the API as JSON from the start means the frontend is swappable: vanilla JS today and a framework SPA tomorrow consume the same contract, so no backend rework is needed to upgrade the UX. Go is chosen as the single backend language for its fit with the boot.dev track and its concurrency model (which suits the rate-limited enrichment worker).

## Considered Options

- **Go + HTMX / html-template (server-rendered HTML fragments):** most cohesive and least JS, but the HTML-fragment endpoints would have to be rebuilt as JSON to reach the eventual SPA. Rejected because C is the stated destination.
- **Python web + Go worker:** doubles the toolchain for no gain here. Rejected.

## Consequences

- Endpoints return JSON; the frontend is a separate concern that can deploy with the app (served as static files by Go) or, at the C stage, independently.
- Cross-origin (CORS) and static-file serving are deployment details to settle when the frontend stage is built.
