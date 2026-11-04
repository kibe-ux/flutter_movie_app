# Load-test results — 5 November 2026

Local route benchmarks show that cached browsing can serve substantially more
requests than the configured provider budgets allow for uncached traffic. They
do not establish production capacity for 50,000 users. Real database latency and
provider allowances need attention before making that commitment.

## Setup

Windows, Node v24.13.0, Intel Core i5-10310U, eight logical CPUs, approximately
15.85 GiB RAM. Source HEAD: `3e105572ed7edf589e1c185c4763ef6af9e949ec`.
Tests ran on 5 November in Africa/Nairobi (4 November UTC). No hosted function
deployment, real provider traffic, APK build or billing change was made.

The actual route modules ran in a separate local process. Memory-store calls
used a 5 ms asynchronous delay; synthetic providers used 100 ms. Production
quotas and the eight-task Wambesha admission limit remained enabled. Catalogue
warmup used four approximately 15.6 KB response pages. Source warmup used 80
UID-scoped entries. These are synthetic workloads, not recorded user sessions.

## Measurements

Successful RPS includes response drain time. P95 is end-to-end latency for 2xx
responses, including generator scheduling delay. The gate also requires zero
generator drops and transport errors. All runs except the 512-concurrency repeat
had zero transport errors; that repeat recorded 225 connection errors.

| Scenario | Offered RPS / seconds | Scheduled | HTTP 200 | HTTP 503 | Generator drops | Successful RPS | Successful p95 ms | Gate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Cached catalogue, memory | 100 / 10 | 1,000 | 1,000 | 0 | 0 | 99.81 | 30.34 | Pass |
| Cached catalogue, memory | 300 / 10 | 3,000 | 3,000 | 0 | 0 | 299.57 | 29.44 | Pass |
| Cached catalogue, memory | 600 / 10 | 6,000 | 6,000 | 0 | 0 | 598.85 | 28.80 | Pass |
| Cold catalogue, memory | 100 / 10 | 1,000 | 600 | 400 | 0 | 59.57 | 203.30 | Fail |
| Cached sources, memory, 80 users | 200 / 10 | 2,000 | 2,000 | 0 | 0 | 199.67 | 39.23 | Pass |
| Cold sources, memory | 100 / 10 | 1,000 | 120 | 880 | 0 | 11.95 | 189.49 | Fail |
| Search API, memory | 25 / 10 | 250 | 222 | 28 | 0 | 22.21 | 159.20 | Fail |
| Cached catalogue, memory, 256 in flight | 1,000 / 50 | 50,000 | 49,956 | 0 | 44 | 998.38 | 57.45 | Fail |
| Cached catalogue, memory, 512 in flight (repeat) | 1,000 / 50 | 50,000 | 48,083 | 0 | 1,692 | 960.89 | 525.07 | Fail |
| Cached catalogue, real Neon | 10 / 10 | 100 | 100 | 0 | 0 | 9.84 | 304.39 | Fail |

The 50,000-arrival run used 50,000 possible identities. It served every request
that the generator sent, but dropped 44 arrivals at its outstanding-request cap.
Its 99.912% success rate does not pass the stricter zero-drop gate. This is not
50,000 simultaneous requests. Process sampled RSS peaked at 136.9 MiB; CPU use
averaged about 0.63 of one core. These figures exclude the generator process and
do not establish cloud instance sizing or a long-term memory ceiling.

Repeating 50,000 arrivals with a 512-request cap did not resolve the failure:
48,083 succeeded, 1,692 were dropped and 225 had connection errors. Successful
p95 rose to 525.07 ms; generator scheduling p95 was 63.24 ms and server event-loop
p95 was 70.32 ms. Raising concurrency worsened this run. The shared workstation
and generator may contribute, and these measurements do not isolate a single
cause. Do not claim reliable 1,000 RPS from either run. The highest short warm
catalogue profile that passed was 600 offered RPS for ten seconds; that is not a
verified sustained production limit.

Cold catalogue used exactly 600 simulated TMDB upstream calls and exhausted its
shared minute budget. Cold sources used 120 simulated Wambesha calls; 776 requests
were rejected by the upstream quota and 104 by admission capacity. The search
test crossed a fixed-minute boundary and used 222 calls across two windows. Its
observed short-term rate is not the sustainable 120-per-minute provider budget.
Search here measures one route call; Flutter can make another batch-title call
per interaction.

The isolated Neon probe performed 100 database queries during measurement, even
though all 100 catalogue responses were cache hits. Median latency was 261.42 ms,
p95 304.39 ms and p99 790.75 ms. It passed availability but missed the provisional
250 ms p95 goal. This includes workstation-to-database networking; it is not a
measurement of a hosted function near its database, nor a database saturation
test. The temporary schema was successfully dropped.
An independent metadata query afterward confirmed zero remaining schemas matching
the load-test schema pattern. Backend verification passed 86 tests, with one
opt-in PostgreSQL integration test skipped.

## Decisions

Keep cache reuse and quota protection. Do not raise provider limits based on
local compute throughput. At 120 Wambesha upstream calls per minute, a search
interaction needing two calls consumes the sustained budget at one search per
second, before other provider work. Confirm the provider allowance and measure
the real cache-miss/search/source mix before selecting higher limits.

The next capacity gate is an instrumented staging run with the production host,
real authentication/database paths, explicit provider allowances, realistic
bursts, a 30–60 minute soak and cold starts. Measure the hosted quota-query latency
before choosing an optimization. No production traffic burst was performed.
Firebase, App Check, forum/rewards/deletion operations and movie-file transfers
were excluded. App Check and backup recovery verification remain separate work.

Commands, assumptions, planning arithmetic and report interpretation are in the
[load-testing guide](LOAD_TESTING.md). Detailed JSON evidence is under the ignored
local `reports/load-tests/` directory. Preserve that evidence separately for
future comparisons; the initial batch reports label their post-run timestamps
as `recordedAtUtc`. Later reports include both start and completion timestamps.
