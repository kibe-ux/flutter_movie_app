# Backend load testing

Use these tests to measure route behavior and provider protection before setting
a user-capacity target. They do not certify production for 50,000 concurrent users.
See the [measured results](load-testing-results-2026-11-05.md).

## Run locally

Install the backend's locked dependencies with `npm ci`, then:

```sh
cd backend
npm run load:test -- --scenario=catalogue-warm --rate=100 --duration=10
npm run load:test -- --scenario=catalogue-cold --rate=100 --duration=10
npm run load:test -- --scenario=source-warm --rate=200 --duration=10
npm run load:test -- --scenario=source-cold --rate=100 --duration=10
npm run load:test -- --scenario=search --rate=25 --duration=10
npm run load:test -- --scenario=catalogue-warm --rate=1000 --duration=50
npm run load:test -- --scenario=catalogue-warm --rate=1000 --duration=50 --concurrency=512
```

The runner starts the actual catalogue/Wambesha route modules in a child process
bound to `127.0.0.1`. Authentication and providers are synthetic. It never calls
the real movie providers and cannot accept a remote HTTP target. No APK or runtime
deployment is needed. Synthetic provider URLs cannot deliver movie files.

Defaults: 50,000 possible synthetic identities, 256 requests in flight, 5 ms
asynchronous delay per memory-store operation, 100 ms simulated provider delay,
production quota values. Each scenario starts a fresh process and store. Warmup
preloads four catalogue pages or up to 80 UID-scoped source entries, then resets
measurement counters. Warmup still consumes quotas. The source-warm workload
reuses those 80 users; it does not simulate 50,000 cached source users.

Options use `--name=value`:

| Option | Values |
| --- | --- |
| `scenario` | `catalogue-warm`, `catalogue-cold`, `source-warm`, `source-cold`, `search` |
| `rate` | 1–2,000 scheduled requests/second |
| `duration` | 1–60 seconds |
| `users` | 1–50,000 synthetic identities |
| `concurrency` | 1–512 maximum outstanding requests |
| `store` | `memory` (default), `neon` |
| `store-latency` | 0–250 ms per memory-store operation |
| `provider-latency` | 0–1,000 ms simulated upstream delay |
| `profile` | `production` (default), `capacity` |

`capacity` raises only fixture quota values to explore compute throughput; it
does not change production settings or the real Wambesha eight-task admission
limit. Never use that profile as evidence that the provider plan allows the load.

The search scenario exercises a single search API request. The app can follow
search with a batch-title request, so a full search interaction can cost two
provider calls. This scenario does not model the entire Flutter search flow.

## Optional isolated Neon probe

With the normal private `backend/.env` database configuration available:

```sh
npm run load:test -- --store=neon --rate=10 --duration=10 --concurrency=20
```

This uses the real database adapter with a random `moviehub_load_<16 hex>`
schema, fully qualified table names, a separate advisory-lock namespace, and a
2 MiB cache-payload budget. It does not use production cache rows or quota keys.
It shares the database's compute and network, so run off peak. The runner enforces
at most 20 RPS, 10 seconds, 20 outstanding requests, and production quota values.
This is a latency probe, not a maximum database-capacity test.

Normal shutdown drops only that validated test schema and records cleanup
success. A forced process/host termination or database outage can interrupt
cleanup. Inspect any residual `moviehub_load_` schemas, verify ownership and the
recorded run before removing an orphan. Do not remove production tables.

## Read results

Each run writes an ignored JSON report under `reports/load-tests/`, including
source hashes, source commit, host/Node information and cleanup status. Keep these
reports in durable operational storage when comparing releases. The commit is
the checked-out HEAD; hashes identify the actual runtime source under test.

The generator schedules arrivals independently of response completion. Requests
beyond its concurrency bound are reported as dropped arrivals, rather than
silently reducing the offered rate. Latency includes generator scheduling delay;
reports also show that delay separately. RPS uses actual elapsed time including
drain time. Success percentiles include only 2xx responses; inspect status counts
and availability alongside them. Quota rejection protects the service, but still
counts as an unavailable request for the provisional user-facing SLO.

The provisional gate is 99% successful scheduled arrivals, successful p95 at
most 250 ms, zero dropped arrivals and zero transport errors. Agree on product
SLOs before treating this as a release requirement. Inspect provider calls, store
operations, CPU, sampled process RSS/heap and event-loop delay. These are process
measurements, not host-wide or cloud billing measurements. Peak memory is sampled
every 100 ms. Fixed-minute quota windows can permit more calls when a run crosses
a window boundary; retain timestamps and counts.

The memory store is a latency-controlled stand-in, not a PostgreSQL capacity or
storage-eviction model. Provider payloads and latency are fixed synthetic samples.
The route logs are counted without production log-sink IO. The generator and
server have separate processes but share one physical machine. Firebase token
verification, App Check, Firestore forum/rewards/deletion operations, real provider
network behavior, hosted cold starts/autoscaling and movie downloads are excluded.

## Plan for 50,000 accounts

Account count alone cannot establish request capacity. For example, assuming
two backend API calls per minute per active user:

| Peak active share | Active users | Mean backend request rate |
| --- | ---: | ---: |
| 1% | 500 | 16.7 RPS |
| 5% | 2,500 | 83.3 RPS |
| 10% | 5,000 | 166.7 RPS |

These are planning assumptions, not observed user behavior. Add launch bursts,
retries, search, source checks, cache misses and authenticated database work.

Current global defaults allow 600 TMDB and 120 Wambesha upstream calls per minute
across instances. Wambesha therefore has a sustained budget of two upstream calls
per second; a two-call search interaction would use the whole budget at one search
per second, before source checks or other features. Cached requests still consume
shared per-user quota operations in PostgreSQL. Wambesha source reuse is UID-scoped
and bounded per process, so unrelated users cannot all share one delivery answer.

Before promising 50,000-user capacity, run a separate staging deployment with the
same hosting, database configuration and release flags. Use dedicated test
identities and synthetic records. Measure the real browsing/search/source mix,
Firebase and Firestore latency, hosting concurrency/cold starts, provider budgets,
database query latency/connections, and retry behavior. Ramp to the expected peak
with explicit headroom, then soak for 30–60 minutes and repeat after a cold start.
Use controlled fault injection to verify timeouts and recovery. Avoid real reward
credits, deletion requests and movie transfers. Coordinate any real-provider test
against the provider's documented allowance; agree on stop conditions for 5xx,
latency and database pressure before running it.

Do not increase provider quotas merely because a local compute benchmark passes.
