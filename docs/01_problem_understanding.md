# Phase 1: Problem Understanding

**Team T0030 · Google Maps Navigation Database (PostgreSQL)**

| # | What the business needs (in our words) | Stakeholder affected | Type | Queries |
|---|---|---|---|---|
| P1 | "Near me" and "open now" results must appear instantly. Places that close after midnight (closes < opens) must be matched correctly, not dropped or slow. | Traveller/driver, Search team | Customer-facing / real-time | R01, R03, R04, R23 |
| P2 | A place page (details, today's hours, newest reviews) and the Saved tab must load without lag. Writing a review or saving a place must stay fast. | Traveller, Local Guide, business owner, Places team | Customer-facing / real-time | R02, R05, R06, W02, W03 |
| P3 | The live traffic and incident layers must refresh every minute. This needs the latest reading per segment and recent incidents only, not a scan of all history. | Driver, Traffic team | Customer-facing / real-time | R07, R08, R10, W05 |
| P4 | "Typical traffic" charts (average speed by hour) and road-safety reports must come back quickly although they aggregate a lot of history. | Traffic team, road-safety analysts | Reporting / analytics | R09, R25 |
| P5 | Pressing "Start" must be instant (one insert). ETA accuracy, re-routing hotspots and trends must be reportable from the same data. | Driver, Routing & ETA team | Mixed: W01 is real-time; R11, R12, R17, R18 are analytics | R11, R12, R17, R18, W01 |
| P6 | The "places never used as a start point" list is empty, which is impossible. This is a **wrong-result bug**, not only a speed problem. It is likely caused by NULLs in `origin_place_id` combined with `NOT IN`. | Data-quality team | Reporting / analytics (correctness) | R13 |
| P7 | Data-quality checks (rating or count not matching reviews, closed places still navigated to, places without hours, duplicate listings) must finish instead of timing out, and the nightly recompute must finish within its window. | Data-quality team, business owner, moderation | Reporting / analytics (batch) | R15, R16, R21, R24, W04 |
| P8 | Leaderboards, moderation lists and health reports must stay usable when navigation volume grows 20×. | Local Guide, moderation, Community/Analytics | Reporting / analytics (scale) | R14, R19, R20, R22 |

**Why the classification matters:** customer-facing queries need a few ms and must scale with log n through index lookups. Reporting queries can take seconds, so they can use summary tables, materialized views and replicas. This fits the targets in README §5.2 (real-time < 5 ms, interactive < 250 ms, reports < 5 s, batch < 2 s).

## Assumptions
1. Seed data is a faithful export of production: 200,000 navigation sessions from 1 Jan 2025 to 30 Jun 2026, all timestamps in IST (+05:30).
2. Reads are far more common than writes. Writes (W01–W05) are small and frequent, so indexes must not slow them noticeably.
3. Reporting queries tolerate slightly stale data. Real-time queries do not.
4. Missing values are meaningful, not errors: `origin_place_id` is NULL when navigation starts from GPS, `user_id` is NULL for anonymous sessions, and `actual_minutes` is NULL until the trip is completed.
5. A place may close after midnight (`closes < opens`), so a "closing time earlier than opening time" is valid data, not an error.
6. `places.avg_rating` and `review_count` are intentionally denormalized for fast page loads and refreshed by the nightly job (W04).
7. Query results must not change while optimizing. No data changes and no server-setting tricks are allowed.
8. The large dataset (~20×) will have the same schema and similar data distribution.