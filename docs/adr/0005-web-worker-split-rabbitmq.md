# Web and worker split, decoupled by RabbitMQ

The system runs as two Go processes — a web/API process and a background worker process — decoupled by a RabbitMQ message broker. When the web side encounters an App with no cached metadata, it *publishes* an "enrich appid" message; the worker *consumes* it, calls the rate-limited `appdetails` endpoint behind a token bucket, and writes the result to Postgres. User requests never block on enrichment.

For this project's traffic an in-process channel + worker goroutine would functionally suffice, so RabbitMQ is deliberately more than the scale strictly demands. The choice is intentional: it is a boot.dev track competency, the enrichment workload is a genuine (non-contrived) reason for a broker, and it provides durability (pending enrichments survive a worker restart), decoupling, and independent worker lifecycle. This is the project's headline infrastructure story.

## Considered Options

- **Single process, in-process queue:** simplest, works at this scale, but no durability and no pub/sub demonstration. Rejected.

## Consequences

- RabbitMQ is an additional service in Docker Compose.
- Requires handling connection/reconnection, message acknowledgement, and redelivery semantics.
- The broker is available to carry other job types later (e.g. background library refresh), not just enrichment.
