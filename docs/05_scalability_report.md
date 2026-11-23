# CP4 Scalability Report
## 1. Test environment and dataset
- Database: `gmaps_large` (PostgreSQL 18.6 via Postgres.app).
- Large dataset loaded: 18,730,897 rows across the 11 supplied CSV tables.
- `navigation_sessions`: 4,000,000 rows.
- Benchmarks: 30 optimized workload queries, 3 runs per query; values below are the reported average execution times in milliseconds.
- Growth compares the optimized seed-data average with the large-data average **before partitioning**. Partitioning comparison is shown separately.
## 2. Results and performance targets
| Query | Seed avg (ms) | Large avg before partitioning (ms) | Growth (×) | Target (ms) | Before partitioning | Large avg after partitioning (ms) | After partitioning |
|---|---:|---:|---:|---:|---|---:|---|
| R01 | 0.527 | 1.210 | 2.3× | < 5 | PASS | 1.524 | PASS |
| R02 | 0.155 | 0.351 | 2.3× | < 5 | PASS | 0.415 | PASS |
| R03 | 0.838 | 5.737 | 6.8× | < 250 | PASS | 22.656 | PASS |
| R04 | 2.385 | 14.778 | 6.2× | < 5 | MISS | 16.755 | MISS |
| R05 | 0.276 | 0.682 | 2.5× | < 5 | PASS | 0.507 | PASS |
| R06 | 0.148 | 0.356 | 2.4× | < 5 | PASS | 0.350 | PASS |
| R07 | 5.532 | 138.724 | 25.1× | < 5 | MISS | 134.954 | MISS |
| R08 | 0.187 | 1.462 | 7.8× | < 5 | PASS | 1.376 | PASS |
| R09 | 0.313 | 0.295 | 0.9× | < 250 | PASS | 0.220 | PASS |
| R10 | 0.217 | 1.347 | 6.2× | < 5 | PASS | 1.282 | PASS |
| R11 | 25.272 | 818.921 | 32.4× | < 5000 | PASS | 1570.164 | PASS |
| R12 | 1.440 | 23.462 | 16.3× | < 250 | PASS | 44.850 | PASS |
| R13 | 6.609 | 283.360 | 42.9× | < 250 | MISS | 2131.155 | MISS |
| R14 | 7.938 | 125.234 | 15.8× | < 5000 | PASS | 113.873 | PASS |
| R15 | 29.602 | 1003.754 | 33.9× | < 5000 | PASS | 1008.766 | PASS |
| R16 | 4.480 | 153.805 | 34.3× | < 5000 | PASS | 171.912 | PASS |
| R17 | 31.556 | 1035.547 | 32.8× | < 5000 | PASS | 2477.669 | PASS |
| R18 | 14.995 | 377.279 | 25.2× | < 5000 | PASS | 444.358 | PASS |
| R19 | 25.950 | 929.175 | 35.8× | < 5000 | PASS | 1387.278 | PASS |
| R20 | 2.021 | 78.904 | 39.0× | < 5000 | PASS | 71.819 | PASS |
| R21 | 15.586 | 646.335 | 41.5× | < 5000 | PASS | 600.390 | PASS |
| R22 | 3.186 | 6.436 | 2.0× | < 250 | PASS | 6.738 | PASS |
| R23 | 0.024 | 0.489 | 20.4× | < 5 | PASS | 0.055 | PASS |
| R24 | 5.103 | 230.180 | 45.1× | < 250 | PASS | 209.048 | PASS |
| R25 | 25.922 | 706.457 | 27.3× | < 5000 | PASS | 665.825 | PASS |
| W01 | 0.757 | 2.056 | 2.7× | < 5 | PASS | 2.356 | PASS |
| W02 | 0.650 | 1.832 | 2.8× | < 5 | PASS | 1.734 | PASS |
| W03 | 0.674 | 2.073 | 3.1× | < 5 | PASS | 2.026 | PASS |
| W04 | 64.865 | 4069.838 | 62.7× | < 2000 | MISS | 3689.001 | MISS |
| W05 | 2.147 | 234.284 | 109.1× | < 2000 | PASS | 224.964 | PASS |

**Target summary:** Before partitioning, 26 of 30 queries met their group target. The four misses were R04 (14.778 ms against 5 ms), R07 (138.724 ms against 5 ms), R13 (283.360 ms against 250 ms), and W04 (4,069.838 ms against 2,000 ms). After partitioning, the same four queries still missed; R13 regressed substantially to 2,131.155 ms. Partitioning should therefore be presented as a date-range scalability design, not as a universal speedup.

## 3. Growth analysis
Using the measured ratio `large average ÷ seed optimized average` (classification: about the same ≤2×; moderate growth >2× and ≤20×; severe growth >20×):
- **About the same (≤2×):** R09 (0.9×) and R22 (2.0×, rounded). R09's indexed time-range lookup remains nearly constant; R22's indexed pagination remains comparatively stable.
- **Moderate growth (>2× to 20×):** R01, R02, R03, R04, R05, R06, R08, R10, R12, R14, W01, W02, W03. These queries are affected by larger candidate sets, joins, or additional index/table work, but their measured growth remains below 20×.
- **Severe growth (>20×):** R07, R11, R13, R15, R16, R17, R18, R19, R20, R21, R23, R24, R25, W04, W05. This group includes broad scans/aggregations, joins over large relations, and batch operations. Ratios should be interpreted alongside absolute latency: for example, R23 grows 20.4× but remains only 0.489 ms before partitioning.

The input dataset is approximately 20× larger for the main navigation workload, but individual query growth is not uniformly 20×: indexed lookups can remain nearly flat, while queries reading a substantial fraction of a large relation or performing broad joins/aggregations can grow sharply. W04 is the batch-workload target miss (4,069.838 ms against 2,000 ms). W05 grows sharply relative to seed data but remains within its target at 234.284 ms.

## 4. What broke at scale and partitioning results
The four large-data target misses before partitioning were R04, R07, R13, and W04. The measurements show that the seed-data optimizations did not fully preserve latency at the larger row counts. The supplied benchmark summary identifies scan nodes; the dominant pattern in the slower analytical/navigation queries is broad access to large relations rather than a single point lookup. No claim is made that these four misses were fixed: the post-partition benchmark still misses all four targets.

`navigation_sessions` was converted to **RANGE partitioning on `started_at`**. The migration copied and verified all 4,000,000 rows, then replaced the original table. It created 18 monthly partitions from January 2025 through June 2026 plus a DEFAULT partition. The observed counts are:
| Partition | Rows | Partition | Rows |
|---|---:|---|---:|
| `p202501` | 227,107 | `p202502` | 205,128 |
| `p202503` | 227,106 | `p202504` | 219,780 |
| `p202505` | 227,107 | `p202506` | 219,780 |
| `p202507` | 227,106 | `p202508` | 227,106 |
| `p202509` | 219,780 | `p202510` | 227,107 |
| `p202511` | 219,780 | `p202512` | 227,106 |
| `p202601` | 227,106 | `p202602` | 205,129 |
| `p202603` | 227,106 | `p202604` | 219,780 |
| `p202605` | 227,106 | `p202606` | 219,780 |

The DEFAULT partition contained no rows in the observed distribution. A bounded June 2026 `EXPLAIN` demonstrated pruning: the plan scanned only `navigation_sessions_p202606` (parallel sequential scan), rather than all monthly partitions. The R12 workload SQL, however, currently has only `started_at >= '2026-06-24'` and no upper bound; therefore it is not limited to the final seven days of June and may legitimately need to consider the DEFAULT partition. Its comment and predicate should be aligned in a future query correction by adding an exclusive upper bound of `2026-07-01` in the same timezone convention.

The partitioned table retains the original nine CHECK constraints and three foreign keys. PostgreSQL partitioned primary keys must include the partition key; accordingly, the primary key is `(session_id, started_at)`. The catalog check confirmed a unique primary index/constraint on those columns. Four additional indexes were created: a partial covering index for completed sessions, a BRIN index on `started_at`, a destination/time index, and a partial origin-place index.

**Partitioning impact:** date-restricted queries can prune irrelevant months, as shown by the June plan. Queries without a restrictive `started_at` predicate must visit many or all partitions; partition overhead can make them slower. This is visible in R13 (283.360 → 2,131.155 ms), R17 (1,035.547 → 2,477.669 ms), R19 (929.175 → 1,387.278 ms), and R11 (818.921 → 1,570.164 ms). R20 improved (78.904 → 71.819 ms), but this is not a broad win. Partitioning is retained for time-based lifecycle management and date pruning, with query design needing to include bounded time predicates wherever semantically correct.

## 5. Storage
- Large database size: **3,153 MB**.
- Table storage: **1,403 MB**.
- Index storage: **1,740 MB**.
- Total relation storage: **3,144 MB** (the small difference from database size is database/catalog and other non-relation overhead).
- Seed database/table/index storage was not captured in the available benchmark evidence, so no seed storage number is invented. For a complete seed-vs-large storage comparison, record `pg_database_size()` and the same relation-size aggregation on the seed database.

## 6. Architecture for 100× volume
### Partitioning
Keep `navigation_sessions` partitioned by monthly RANGE on `started_at`: navigation history and retention are naturally time-oriented, and the bounded June 2026 plan proved pruning to one monthly partition. Maintain future monthly partitions ahead of ingestion and retain a DEFAULT partition as a safety net. Queries intended for a fixed period should use both inclusive lower and exclusive upper bounds. The primary key includes `started_at` because PostgreSQL requires a partitioned unique/primary key to include the partition key. Partitioning is not a substitute for indexes or selective predicates.

### Sharding
For this workload, a **geography-first shard key (city/region)** is the strongest initial choice for place discovery and live traffic: nearby-place, road-segment, and traffic queries are local and can usually be routed to one shard. Replicate global reference data such as travel modes and category definitions. User history is naturally user-centric, so a separate user-to-home-region mapping or a user-history service may be needed; a user travelling across regions can create cross-shard history reads. Cross-city searches and multi-region analytics also become scatter/gather operations. Handle them with bounded fan-out, per-shard aggregation followed by a coordinator merge, and asynchronously maintained global summaries. Avoid user-only sharding as the sole strategy because it makes local traffic and nearby searches cross-shard.

### Read replicas and caching
Send read-heavy, slightly stale-tolerant analytics and historical reporting queries (R11, R14–R21, R25) to read replicas. Cache stable place/category metadata and popular place details; cache eligible nearby-search results and traffic snapshots only with short TTLs and location/time-aware keys. Keep writes W01–W05 on the primary. Route session creation/status changes and any read-after-write or correctness-critical live navigation request to the primary; do not serve stale traffic or session state where it could misroute a user. R01–R10 and R22–R24 should be split by freshness requirement: cache only results whose staleness is acceptable, otherwise use the primary or a low-lag replica.

### Maintenance
Use table- and partition-level autovacuum/analyze settings based on measured update volume, dead tuples, and partition size rather than applying arbitrary global thresholds. Run `ANALYZE` after bulk loads and major partition changes; monitor `pg_stat_user_tables`, dead tuples, vacuum/analyze timestamps, and index growth. Detach/archive or drop expired monthly partitions according to retention policy instead of large row-by-row deletes. Refresh materialized summaries incrementally or on a scheduled cadence for expensive all-time reports. Monitor DEFAULT partition occupancy and create new monthly partitions before each month begins.

## 7. Conclusion and remaining risks
The database successfully loaded and indexed the approximately 18.7-million-row dataset, and the 4-million-row navigation table was migrated into 18 monthly partitions with row-count verification and a demonstrated pruning plan. However, the large-data benchmark does **not** meet every performance target: R04, R07, R13, and W04 remain above target both before and after partitioning. Partitioning provides a sound time-based scaling and retention foundation, but it worsens several unbounded navigation analytics queries. Before claiming readiness for 100× volume, optimize those four queries using their actual execution plans, bound date predicates where semantically correct, and repeat the three-run benchmark. Seed storage comparison is also outstanding because that measurement was not captured. Therefore, the system is a validated prototype for the next scale step, but not yet proven ready for 100× production traffic.
