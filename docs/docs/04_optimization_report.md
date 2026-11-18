# Checkpoint 3: Optimization Report

## Overview
This report details the optimization techniques applied to the CP2 baseline workload. Performance was improved through a combination of B-Tree indexing and query rewriting to enable SARGable (Search Argument Able) condition scanning.

## 1. Indexing Strategy
To prevent sequential scans on the large tables outlined in our schema (`places`, `place_reviews`, `navigation_sessions`, and `traffic_readings`), targeted indexes were added in `05_indexes.sql`.

* **Spatial and Category Filtering:** An index on `places (latitude, longitude)` was added to speed up bounding-box filtering in R01. A partial index on `places (city_id, category_id, avg_rating DESC) WHERE NOT is_permanently_closed` drastically reduces the cost of R04 and R19.
* **Timestamp Scans:** Indexes on `place_reviews (created_at DESC)` and `traffic_readings (recorded_at DESC)` were added to optimize pagination and time-series rollups in R22, R07, R08, and R10.
* **Foreign Key Lookups:** B-Tree indexes were placed on all heavily joined foreign keys, most notably `navigation_sessions (dest_place_id)` and `saved_places (user_id)`.

## 2. Query Rewriting (SARGability and Joins)
Several queries from the baseline `workload_30.sql` forced the planner into sequential scans by wrapping indexed columns in functions. These were rewritten in `06_optimized_queries.sql`:

* **R10 (Incident Layer):** Replaced `DATE(i.reported_at) = '2026-06-30'` with strict timestamp boundaries (`i.reported_at >= '2026-06-30' AND i.reported_at < '2026-07-01'`).
* **R11 (ETA Quality):** Removed `EXTRACT(YEAR FROM started_at) = 2026` in favor of a `> <` timestamp range to allow index utilization.
* **R13 (Data Team):** Replaced the computationally heavy `NOT IN (SELECT...)` with a highly optimized `NOT EXISTS` block.
* **R19 (Health Report):** The baseline query executed two correlated subqueries in the `SELECT` clause for every row. This was rewritten into a single pass utilizing a `LEFT JOIN` and a `GROUP BY`.
* **R20 (Product Analytics):** Removed the `::date BETWEEN` cast in the `WHERE` clause, replacing it with hard timestamp limits to take advantage of the `idx_nav_started` index.