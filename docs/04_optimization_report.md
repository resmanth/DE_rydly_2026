# Phase 4: Optimization Report

Team T0030 · PostgreSQL version: 17.11 · Laptop: Apple Mac (arm64)
Timings come only from `benchmarks/results/baseline/` and `benchmarks/results/optimized/` (3 runs each, averaged).
Every number here must match those raw files.

## 1. Summary

| Metric | Baseline (ms) | Optimized (ms) | Improvement |
|---|---|---|---|
| Total of 30 queries (average) | 13079.192 | 279.355 | 97.86% |

Improvement % = (before − after) / before × 100

## 2. Per-query results

Fill "Before" and "After" from the benchmark CSVs. The "Optimization" column is the planned change; confirm it against the plan files.

| Query | Before (ms) | Problem in plan | Optimization | After (ms) | Improvement | Same result? |
|---|---|---|---|---|---|---|
| R01 | 18.714 | Seq Scan on places, acos() per row | `idx_places_near_open` (partial, INCLUDE) | 0.527 | +97.2% | ✅ (checksum) |
| R02 | 0.480 |  | Already fast via PK on `opening_hours(place_id, weekday)` | 0.155 | +67.7% | ✅ |
| R03 | 13.649 | Seq Scan, ILIKE '%…%' | `idx_places_name_trgm` (pg_trgm GIN) | 0.838 | +93.9% | ✅ |
| R04 | 27.040 | Seq Scan on hours | `idx_places_city_rating` + PK on hours | 2.385 | +91.2% | ✅ |
| R05 | 6.599 | Sort of all reviews of place | `idx_reviews_place_newest` | 0.276 | +95.8% | ✅ |
| R06 | 0.903 | Sort by list, saved_at | `idx_saved_user_list` | 0.148 | +83.6% | ✅ |
| R07 | 25.401 | Seq Scan on traffic, DISTINCT ON sort | `idx_traffic_segment_time`, `idx_segments_city_road` (text_pattern_ops) | 5.532 | +78.2% | ✅ |
| R08 | 6.943 | Seq Scan on traffic | `idx_traffic_heavy_recent` (partial). Note: seed data has **no `STANDSTILL` rows**, so this query returns only `HEAVY` rows | 0.187 | +97.3% | ✅ |
| R09 | 4.478 | Seq Scan, EXTRACT per row | `idx_traffic_segment_time` (Index Only Scan) | 0.313 | +93.0% | ✅ |
| R10 | 3.822 | DATE() on column blocks index | Range predicate + `idx_incidents_reported` | 0.217 | +94.3% | ✅ (after TZ check) |
| R11 | 62.749 | EXTRACT on column, full scan | Range predicate + `idx_nav_completed_started` | 25.272 | +59.7% | ✅ (after TZ check) |
| R12 | 10.020 | Seq Scan on navigation (time filter) | `idx_nav_started_brin` | 1.440 | +85.6% | ✅ |
| R13 | 19.539 | NOT IN with NULLs | NOT EXISTS + `idx_nav_origin` (partial) | 6.609 | +66.2% | ❌ **Changed on purpose** (see §3) |
| R14 | 18.145 | Sort/aggregate over all reviews | `idx_reviews_created` (Index Only Scan) | 7.938 | +56.3% | ✅ |
| R15 | 26.849 | Seq Scan on reviews, GROUP BY | `idx_reviews_place_newest` (Index Only Scan) | 29.602 | -10.3% | ✅ |
| R16 | 12.387 | Hash join over all navigations | `idx_nav_dest_started` | 4.480 | +63.8% | ✅ |
| R17 | 32.706 | Full aggregate on navigations | `idx_nav_dest_started` (Index Only Scan) | 31.556 | +3.5% | ✅ |
| R18 | 14.634 | Full scan (low selectivity) | None. Explained in §5 | 14.995 | -2.5% | ✅ |
| R19 | 12650.852 | Two correlated subqueries per hospital | One aggregate + LEFT JOIN, `idx_nav_dest_started` | 25.950 | +99.8% | ✅ |
| R20 | 10.113 | Cast on column blocks index | Range predicate + `idx_nav_started_brin` | 2.021 | +80.0% | ✅ (after TZ check) |
| R21 | 20.848 | Anti-join over places | Already NOT EXISTS, unchanged | 15.586 | +25.2% | ✅ |
| R22 | 16.070 | OFFSET 50,000 reads 50k rows | `idx_reviews_created` (index-only walk, still O(offset)) | 3.186 | +80.2% | ✅ |
| R23 | 0.025 | Seq Scan on places | UNIQUE on `plus_code` (automatic index) | 0.024 | +4.0% | ✅ |
| R24 | 4.923 | Nested loop, abs() per pair | `idx_places_name_lat` + range predicate | 5.103 | -3.7% | ✅ |
| R25 | 26.150 | Seq Scan + hash join | `idx_traffic_segment_time` (covering) | 25.922 | +0.9% | ✅ |
| W01 | 1.038 |  | Writes slower by the number of new indexes on navigation_sessions | 0.757 | +27.1% | n/a |
| W02 | 0.808 |  | UNIQUE(place_id, user_id) enables ON CONFLICT | 0.650 | +19.6% | n/a |
| W03 | 0.835 |  | PK on saved_places enables ON CONFLICT | 0.674 | +19.3% | n/a |
| W04 | 40.186 | Scan all reviews + UPDATE | `idx_reviews_place_newest` covers the GROUP BY | 64.865 | -61.4% | ✅ |
| W05 | 2.286 | Seq Scan on incidents | `idx_incidents_expires` | 2.147 | +6.1% | n/a |
| **Total** | 13079.192 | | | 279.355 | 97.86% | |

## 3. Wrong-result query (R13)

The original query is `WHERE p.place_id NOT IN (SELECT n.origin_place_id FROM navigation_sessions n)`.
`origin_place_id` is NULL for every session started from GPS. In SQL, `x NOT IN (…)` is TRUE only when
x is different from every value in the list. When the list contains a NULL, the comparison is NULL,
not TRUE, so no row qualifies. R13 always returns zero rows, which is why the data team sees an empty list (problem P6).
The fix is `NOT EXISTS`, which compares row by row and ignores NULL origins. The result changes on purpose,
so the "same result" proof does not apply to R13.

Verified on seed_data.zip (192,584 of 200,000 sessions have a NULL `origin_place_id`):

| Version | Rows returned |
|---|---|
| Original `NOT IN` (R13) | **0** |
| Fixed `NOT EXISTS` (06_optimized_queries.sql) | **33,368** |

Of the 40,042 places, 33,368 have never been a start point. Confirm the same counts on your own database
(`SELECT count(*) FROM …`) before writing them into the final report.

## 4. Before and after plans for the five biggest improvements

Excerpts from `benchmarks/results/baseline/` and `benchmarks/results/optimized/`:

### 1. R19: Hospital navigation statistics (12,650.852 ms -> 25.950 ms | 487.5x speedup, 99.8% improvement)
* **Before:** `Seq Scan` on `places` with two correlated scalar subplans per row running `Seq Scan on navigation_sessions` (loops=1067, 6,198,052 shared buffer hits):
```text
->  Seq Scan on places p (actual time=12.998..12621.877 rows=1067.00 loops=1)
      SubPlan 1
        ->  Aggregate (actual time=5.914..5.914 rows=1.00 loops=1067)
              ->  Seq Scan on navigation_sessions n (actual time=1.355..5.912 rows=5.09 loops=1067)
                    Filter: (dest_place_id = p.place_id)
```
* **After:** Single-pass `HashAggregate` on `navigation_sessions`, joined via `Hash Right Join` to `places` scanned with `Index Only Scan using idx_places_city_rating` (2,964 shared buffer hits):
```text
->  Hash Right Join (actual time=23.300..26.085 rows=1067 loops=1)
      Hash Cond: (navigation_sessions.dest_place_id = p.place_id)
      ->  HashAggregate (actual time=22.682..24.314 rows=39263 loops=1)
            ->  Seq Scan on navigation_sessions (actual time=0.003..5.378 rows=200000 loops=1)
      ->  Index Only Scan using idx_places_city_rating on places p (actual time=0.022..0.348 rows=6442 loops=1)
```

### 2. R11: Monthly ETA accuracy by travel mode (62.749 ms -> 25.272 ms | 59.7% improvement)
* **Before:** `Parallel Seq Scan on navigation_sessions` filtering with non-sargable `EXTRACT(year FROM started_at) = 2026` (2,950 shared buffer hits):
```text
->  Parallel Seq Scan on navigation_sessions (actual time=96.305..132.020 rows=28149.50 loops=2)
      Filter: (((status)::text = 'COMPLETED'::text) AND (EXTRACT(year FROM started_at) = '2026'::numeric))
```
* **After:** `Index Only Scan using idx_nav_completed_started on navigation_sessions` using sargable range condition (305 shared buffer hits):
```text
->  Index Only Scan using idx_nav_completed_started on navigation_sessions (actual time=0.137..16.050 rows=56299 loops=1)
      Index Cond: ((started_at >= '2026-01-01 00:00:00+05:30'::timestamptz) AND (started_at < '2027-01-01 00:00:00+05:30'::timestamptz))
      Heap Fetches: 0
```

### 3. R04: Late night Saturday restaurants (27.040 ms -> 2.385 ms | 11.3x speedup, 91.2% improvement)
* **Before:** `Hash Join` between `Seq Scan on places` and `Seq Scan on opening_hours` with sorting (3,479 shared buffer hits):
```text
->  Sort (actual time=62.121..62.122 rows=25.50 loops=2)
      Sort Key: p.avg_rating DESC NULLS LAST
      ->  Hash Join (actual time=4.146..62.070 rows=132.00 loops=2)
```
* **After:** `Nested Loop` with pre-sorted `Index Scan using idx_places_city_rating on places` joined via `Index Scan using opening_hours_pkey on opening_hours` (1,203 shared buffer hits):
```text
->  Nested Loop (actual time=0.044..2.078 rows=30 loops=1)
      ->  Index Scan using idx_places_city_rating on places p (actual time=0.019..0.916 rows=192 loops=1)
      ->  Index Scan using opening_hours_pkey on opening_hours h (actual time=0.006..0.006 rows=0 loops=192)
```

### 4. R07: Outer Ring Road latest traffic readings (25.401 ms -> 5.532 ms | 4.6x speedup, 78.2% improvement)
* **Before:** `Seq Scan on road_segments` hash-joined to `Seq Scan on traffic_readings`, followed by sort for DISTINCT ON (1,931 shared buffer hits):
```text
->  Unique (actual time=57.525..58.590 rows=40.00 loops=1)
      ->  Sort (actual time=56.397..56.442 rows=2524.00 loops=2)
            ->  Hash Join (actual time=4.059..55.775 rows=2524.00 loops=2)
```
* **After:** `Nested Loop` of `Index Scan using idx_segments_city_road` on road_segments and `Index Only Scan using idx_traffic_segment_time` on traffic_readings (182 shared buffer hits):
```text
->  Nested Loop (actual time=0.044..2.147 rows=5048 loops=1)
      ->  Index Scan using idx_segments_city_road on road_segments s (actual time=0.020..0.071 rows=40 loops=1)
      ->  Index Only Scan using idx_traffic_segment_time on traffic_readings t (actual time=0.011..0.032 rows=126 loops=40)
```

### 5. R01: Restaurants near Koramangala (18.714 ms -> 0.527 ms | 35.5x speedup, 97.2% improvement)
* **Before:** Full `Seq Scan on places` evaluating trigonometric distance formula on 40,042 rows (915 shared buffer hits):
```text
->  Seq Scan on places (actual time=0.798..45.038 rows=16.00 loops=1)
      Filter: ((NOT is_permanently_closed) AND (latitude >= 12.9262) AND (latitude <= 12.9442) AND (longitude >= 77.6152) AND (longitude <= 77.6338) AND (category_id = 1))
      Rows Removed by Filter: 40026
```
* **After:** `Index Only Scan using idx_places_near_open on places` directly scanning bounding box with covered attributes (9 shared buffer hits):
```text
->  Index Only Scan using idx_places_near_open on places (actual time=0.216..0.316 rows=16 loops=1)
      Index Cond: ((category_id = 1) AND (latitude >= 12.9262) AND (latitude <= 12.9442) AND (longitude >= 77.6152) AND (longitude <= 77.6338))
      Heap Fetches: 0
```

## 5. Queries not sped up

- **R18** (cancelled share per mode): reads all 200,000 sessions and groups into 4 modes. No selective filter, so an index does not help; a sequential scan is the cheapest plan. Only a summary table would help, and it adds staleness.
- **R22** (page 2,001): OFFSET must skip 50,000 index entries, so cost grows with the page number. Keyset pagination would fix it, but the page-number UI cannot use it without a cursor.
- **R12, R25**: aggregate over a large share of the table.

## 6. Write overhead

| Write | Before (ms) | After (ms) | Slowdown / Speedup | Acceptable? |
|---|---|---|---|---|
| W01 (insert navigation) | 1.038 | 0.757 | +27.1% (+0.28 ms) | ✅ Acceptable (<1 ms) |
| W02 (insert review) | 0.808 | 0.650 | +19.6% (+0.16 ms) | ✅ Acceptable (<1 ms) |
| W03 (insert save) | 0.835 | 0.674 | +19.3% (+0.16 ms) | ✅ Acceptable (<1 ms) |
| W04 (update ratings) | 40.186 | 64.865 | -61.4% (-24.68 ms) | ✅ Acceptable for nightly batch job |
| W05 (delete incidents) | 2.286 | 2.147 | +6.1% (+0.14 ms) | ✅ Acceptable (~2 ms) |

Explain the cause for each slowdown: one index maintained per insert, and how many indexes now sit on `navigation_sessions`.

## 7. Index storage

Run this and paste the output:

```sql
SELECT c.relname AS object, pg_size_pretty(pg_relation_size(c.oid)) AS size, c.relkind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'gmaps'
ORDER BY pg_relation_size(c.oid) DESC;
```

```text
               object               |    size    | relkind 
------------------------------------+------------+---------
 navigation_sessions                | 23 MB      | r
 traffic_readings                   | 15 MB      | r
 opening_hours                      | 13 MB      | r
 idx_traffic_segment_time           | 12 MB      | i
 idx_nav_dest_started               | 9704 kB    | i
 places                             | 7296 kB    | r
 idx_nav_completed_started          | 7184 kB    | i
 place_reviews                      | 6208 kB    | r
 idx_reviews_place_newest           | 6008 kB    | i
 opening_hours_pkey                 | 5576 kB    | i
 traffic_readings_pkey              | 5496 kB    | i
 navigation_sessions_pkey           | 4408 kB    | i
 idx_reviews_created                | 3584 kB    | i
 users                              | 3408 kB    | r
 idx_places_near_open               | 3048 kB    | i
 idx_places_city_rating             | 3032 kB    | i
 idx_places_name_lat                | 3032 kB    | i
 saved_places                       | 2872 kB    | r
 idx_places_name_trgm               | 2552 kB    | i
 idx_saved_user_list                | 2536 kB    | i
 place_reviews_place_id_user_id_key | 2416 kB    | i
 users_email_key                    | 2352 kB    | i
 place_reviews_pkey                 | 1984 kB    | i
 saved_places_pkey                  | 1904 kB    | i
 places_phone_key                   | 1640 kB    | i
 idx_traffic_heavy_recent           | 1448 kB    | i
 places_plus_code_key               | 1248 kB    | i
 places_website_key                 | 1224 kB    | i
 incident_reports                   | 912 kB     | r
 users_pkey                         | 896 kB     | i
 places_pkey                        | 896 kB     | i
 idx_incidents_reported             | 776 kB     | i
 incident_reports_pkey              | 280 kB     | i
 idx_incidents_expires              | 280 kB     | i
 road_segments                      | 240 kB     | r
 idx_nav_origin                     | 176 kB     | i
 road_segments_pkey                 | 64 kB      | i
 idx_segments_city_road             | 56 kB      | i
 idx_nav_started_brin               | 24 kB      | i
 cities_pkey                        | 16 kB      | i
 place_categories_category_name_key | 16 kB      | i
 place_categories_pkey              | 16 kB      | i
 cities_city_name_key               | 16 kB      | i
 place_categories                   | 8192 bytes | r
 cities                             | 8192 bytes | r
```

| Index | Table | Index size | Table size | Index / table |
|---|---|---|---|---|
| idx_traffic_segment_time | traffic_readings | 12 MB | 15 MB | 81.7% |
| idx_nav_dest_started | navigation_sessions | 9704 kB | 23 MB | 41.8% |
| idx_nav_completed_started | navigation_sessions | 7184 kB | 23 MB | 30.9% |
| idx_reviews_place_newest | place_reviews | 6008 kB | 6208 kB | 96.8% |
| idx_reviews_created | place_reviews | 3584 kB | 6208 kB | 57.7% |
| idx_places_near_open | places | 3048 kB | 7296 kB | 41.8% |
| idx_places_name_lat | places | 3032 kB | 7296 kB | 41.6% |
| idx_places_city_rating | places | 3032 kB | 7296 kB | 41.6% |
| idx_places_name_trgm | places | 2552 kB | 7296 kB | 35.0% |
| idx_saved_user_list | saved_places | 2536 kB | 2872 kB | 88.3% |
| idx_traffic_heavy_recent | traffic_readings | 1448 kB | 15 MB | 9.8% |
| idx_incidents_reported | incident_reports | 776 kB | 912 kB | 85.1% |
| idx_incidents_expires | incident_reports | 280 kB | 912 kB | 30.7% |
| idx_nav_origin | navigation_sessions | 176 kB | 23 MB | 0.8% |
| idx_segments_city_road | road_segments | 56 kB | 240 kB | 23.3% |
| idx_nav_started_brin | navigation_sessions | 24 kB | 23 MB | 0.1% |

## 8. Time-zone assumption

R10, R11 and R20 were rewritten from functions on the timestamp (`DATE()`, `EXTRACT`, `::date`) into ranges
with the explicit offset `+05:30`. Checked on seed_data.zip: every `started_at`, `reported_at` and `recorded_at`
value ends in `+05:30`, so the ranges select the same rows **only if the session timezone is also Asia/Kolkata**.
Run `SHOW timezone;` and confirm that the original and rewritten queries return the same row count.

## 9. Seed-data facts that affect the results

- `congestion_level` takes only `LOW`, `MODERATE` and `HEAVY` (136,661 / 83,112 / 30,227 rows in the readings of the seed data; no `STANDSTILL`).
- 1,167 places are permanently closed (R16 candidates).
- 1,431 places have a stored `avg_rating` that does not match their reviews, and 558 have a wrong `review_count` (R15 returns these).
- 4,004 places have no opening hours (R21).
- 9,359 opening-hours rows close before they open (overnight hours; R04 handles them).