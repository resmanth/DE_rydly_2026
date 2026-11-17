# Baseline timings (CP2)

Method: `EXPLAIN (ANALYZE, BUFFERS)`, 3 runs per query, average of the three `Execution Time` values. Produced with `benchmarks/run_benchmark.sh gmaps_db baseline` on the seed data, with no indexes beyond PK/UNIQUE. Raw plans: `benchmarks/results/baseline/`.

## Timing table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---|---|---|---|
| R01: Restaurants within ~1 km of Koramangala | READ | 45.781 | 4.149 | 6.212 | 18.714 |
| R02: Place page: place 18 + Tuesday hours | READ | 1.358 | 0.039 | 0.043 | 0.480 |
| R03: Bengaluru places with 'biryani' in name | READ | 14.459 | 13.556 | 12.932 | 13.649 |
| R04: Bengaluru restaurants open at 23:30 Saturday | READ | 64.844 | 7.921 | 8.354 | 27.040 |
| R05: 10 newest reviews of place 18 | READ | 19.524 | 0.138 | 0.134 | 6.599 |
| R06: User 1005's saved places by list | READ | 2.585 | 0.062 | 0.062 | 0.903 |
| R07: Latest reading per Outer Ring Road segment | READ | 58.625 | 8.437 | 9.140 | 25.401 |
| R08: Heavy/standstill traffic since 18:00 on 30 Jun 2026 | READ | 7.175 | 6.849 | 6.804 | 6.943 |
| R09: Avg speed by hour on segment 5 | READ | 4.886 | 4.376 | 4.173 | 4.478 |
| R10: Bengaluru incidents on 30 Jun 2026 | READ | 9.934 | 0.732 | 0.799 | 3.822 |
| R11: ETA error per mode per month, 2026 | READ | 142.500 | 23.358 | 22.389 | 62.749 |
| R12: Top 10 Mumbai destinations, last 7 days of June | READ | 10.196 | 9.935 | 9.928 | 10.020 |
| R13: Places never used as a navigation origin | READ | 20.483 | 18.800 | 19.333 | 19.539 |
| R14: Local Guides leaderboard 2026 | READ | 37.733 | 8.233 | 8.469 | 18.145 |
| R15: Places whose rating/review count mismatch reviews | READ | 27.376 | 26.201 | 26.971 | 26.849 |
| R16: Closed places still navigated to (2026) | READ | 12.791 | 12.351 | 12.020 | 12.387 |
| R17: Destinations with most re-routing (>=5 trips) | READ | 35.478 | 31.058 | 31.583 | 32.706 |
| R18: Cancelled % per travel mode | READ | 16.678 | 13.625 | 13.599 | 14.634 |
| R19: Bengaluru hospitals with navigation count + last time | READ | 12622.760 | 12546.176 | 12783.621 | 12650.852 |
| R20: Navigations per day + running total, June 2026 | READ | 10.716 | 10.014 | 9.610 | 10.113 |
| R21: Places without opening hours per category | READ | 21.399 | 20.378 | 20.768 | 20.848 |
| R22: Reviews page 2,001 (OFFSET 50000) | READ | 16.812 | 15.639 | 15.758 | 16.070 |
| R23: Place lookup by Plus Code | READ | 0.026 | 0.024 | 0.025 | 0.025 |
| R24: Duplicate Bengaluru restaurants within ~100 m | READ | 5.192 | 4.808 | 4.770 | 4.923 |
| R25: % readings over speed limit per road type | READ | 26.606 | 25.343 | 26.500 | 26.150 |
| W01: Start navigation (INSERT) | WRITE | 1.860 | 0.589 | 0.665 | 1.038 |
| W02: Write a review (INSERT ... ON CONFLICT) | WRITE | 1.294 | 0.546 | 0.583 | 0.808 |
| W03: Save a place (INSERT ... ON CONFLICT) | WRITE | 1.024 | 0.542 | 0.940 | 0.835 |
| W04: Nightly recompute of rating/review_count (UPDATE) | WRITE | 53.000 | 36.277 | 31.281 | 40.186 |
| W05: Delete expired incident reports (DELETE) | WRITE | 2.553 | 2.121 | 2.183 | 2.286 |
| **Total (sum of all 30)** | | | | | **13079.191** |

## Scan type and reason

| Query | Scan type (from plan) | Why it is slow or fast |
|---|---|---|
| R01 | Seq Scan on places | No index on category/lat/lng, so all 40k places are read and filtered; the distance math only runs on the few survivors. |
| R02 | Index Scan using places_pkey on places ; Index Scan using opening_hours_pkey on opening_hours | Primary-key lookups on places and opening_hours (place_id, weekday), so it touches one row each. |
| R03 | Seq Scan on places | ILIKE '%biryani%' has a leading wildcard, which a B-tree cannot use; every name is checked. |
| R04 | Seq Scan on opening_hours ; Seq Scan on places | No index on city/category/weekday; opening_hours (252k rows) is scanned and the open-past-midnight logic is evaluated per row. |
| R05 | Bitmap Heap Scan on place_reviews ; Bitmap Index Scan on place_reviews_place_id_user_id_key ; Index Scan using users_pkey on users | Few reviews per place; the (place_id, user_id) unique index finds them via bitmap scan, then a tiny sort and a PK join to users. |
| R06 | Index Scan using saved_places_pkey on saved_places ; Index Scan using places_pkey on places | The saved_places primary key starts with user_id, so the user's rows are found directly; places are joined by PK. |
| R07 | Seq Scan on traffic_readings ; Seq Scan on road_segments | traffic_readings (250k) is fully scanned; no index on segment_id/recorded_at, and DISTINCT ON needs a sort. |
| R08 | Seq Scan on traffic_readings ; Index Scan using road_segments_pkey on road_segments | No index on recorded_at/congestion_level, so all 250k readings are read although few rows match. |
| R09 | Seq Scan on traffic_readings | No index on segment_id, so the whole readings table is scanned to find one segment's rows. |
| R10 | Seq Scan on incident_reports ; Seq Scan on road_segments | DATE(reported_at) wraps the column in a function (not sargable) and there is no index on incident_reports. |
| R11 | Seq Scan on navigation_sessions | EXTRACT(YEAR ...) is not sargable and there is no index on started_at/status; all 200k sessions are read and aggregated. |
| R12 | Seq Scan on navigation_sessions ; Seq Scan on places | No index on started_at or dest_place_id; sessions are scanned, then joined to places. |
| R13 | Seq Scan on places ; Seq Scan on navigation_sessions | Hashed NOT IN over all sessions; fast, but returns ZERO rows because origin_place_id contains NULLs (NOT IN + NULL = no rows). This is the wrong-result query (P6). |
| R14 | Seq Scan on place_reviews ; Seq Scan on users | No index on place_reviews.created_at; all reviews are scanned, then joined to users and grouped. |
| R15 | Seq Scan on place_reviews ; Seq Scan on places | Must aggregate every review per place and compare with stored values, so a full read of place_reviews and places is inherent. |
| R16 | Seq Scan on navigation_sessions ; Seq Scan on places | No index on dest_place_id/started_at; sessions are scanned and joined to closed places. |
| R17 | Seq Scan on navigation_sessions | Groups all 200k sessions by dest_place_id; no index and the query touches the whole table. |
| R18 | Seq Scan on navigation_sessions | Aggregates all sessions by travel_mode, so a full scan is inherent for this report. |
| R19 | Seq Scan on place_categories ; Seq Scan on places ; Seq Scan on navigation_sessions | Two correlated subqueries per hospital, each doing a full scan of 200k sessions (no index on dest_place_id). This is the slowest query. |
| R20 | Seq Scan on navigation_sessions | started_at::date is not sargable; all sessions are scanned and then grouped by day. |
| R21 | Seq Scan on opening_hours ; Seq Scan on places ; Seq Scan on place_categories | NOT EXISTS anti-join must read all opening_hours and places; a large share of the data is needed. |
| R22 | Seq Scan on place_reviews | OFFSET 50000 forces the sort of all reviews by created_at and throws away the first 50,000 rows. |
| R23 | Index Scan using places_plus_code_key on places | UNIQUE index on plus_code gives a single-row index lookup. |
| R24 | Seq Scan on places | Self-join of places on name with no index on name/city/category, so a hash join over the places table. |
| R25 | Seq Scan on traffic_readings ; Seq Scan on road_segments | Joins all 250k traffic readings to road_segments and aggregates per road type, so a full read of traffic_readings is inherent; the scan is a Seq Scan on traffic_readings plus a small Seq Scan on road_segments. |
| W01 | (no scan) | Single-row INSERT; only primary-key/FK checks and few indexes to maintain. |
| W02 | (no scan) | Single-row INSERT; the ON CONFLICT check uses the (place_id, user_id) unique index. |
| W03 | (no scan) | Single-row INSERT; the conflict check uses the primary key. |
| W04 | Seq Scan on places ; Seq Scan on place_reviews | Aggregates all reviews and updates places rows that differ; both tables are scanned. |
| W05 | Seq Scan on incident_reports | No index on expires_at, so incident_reports is scanned to find rows to delete. |
