-- Phase 4 indexes (CP3). Every index names the queries it serves.
-- Run after 01_schema.sql and 02_load_data.sql, then ANALYZE.
SET search_path TO gmaps, public;

-- pg_trgm is needed for ILIKE '%text%' (R03)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- R01 "near me": equality on category_id, then the lat/long bounding box.
-- Partial index matches the NOT is_permanently_closed filter; INCLUDE covers the output
-- columns so the plan can be an Index Only Scan.
CREATE INDEX idx_places_near_open
    ON places (category_id, latitude, longitude)
    INCLUDE (place_id, name, avg_rating)
    WHERE NOT is_permanently_closed;

-- R03 "biryani" search: trigram GIN for ILIKE '%biryani%'.
CREATE INDEX idx_places_name_trgm
    ON places USING gin (name gin_trgm_ops);

-- R03 / R04 / R24: city filter, then best-rated first (matches ORDER BY avg_rating DESC).
CREATE INDEX idx_places_city_rating
    ON places (city_id, avg_rating DESC NULLS LAST)
    INCLUDE (place_id, name, review_count, category_id);

-- R05 newest reviews of one place; also serves R15 and W04 (GROUP BY place_id, rating).
-- review_text is included, so the index is larger; the trade-off is reported in 04.
CREATE INDEX idx_reviews_place_newest
    ON place_reviews (place_id, created_at DESC)
    INCLUDE (review_id, user_id, rating, photo_count, review_text);

-- R22 moderation page and R14 leaderboard: global newest-first order and date range.
CREATE INDEX idx_reviews_created
    ON place_reviews (created_at DESC)
    INCLUDE (review_id, place_id, user_id, rating, photo_count);

-- R06 Saved tab: one user's rows, grouped by list, newest first.
CREATE INDEX idx_saved_user_list
    ON saved_places (user_id, list_name, saved_at DESC)
    INCLUDE (place_id);

-- R07 latest reading per segment; R09 hourly profile of one segment; R25 join from segment.
CREATE INDEX idx_traffic_segment_time
    ON traffic_readings (segment_id, recorded_at DESC)
    INCLUDE (avg_speed_kmph, congestion_level);

-- R07 LIKE 'Outer Ring Road%' prefix search needs text_pattern_ops to use btree.
CREATE INDEX idx_segments_city_road
    ON road_segments (city_id, road_name text_pattern_ops);

-- R08 heavy or standstill traffic since a timestamp. Partial: only the rows that match.
-- Seed data has no STANDSTILL rows, so only HEAVY matches today; the predicate is kept for the business rule.
CREATE INDEX idx_traffic_heavy_recent
    ON traffic_readings (recorded_at DESC)
    INCLUDE (segment_id, avg_speed_kmph, congestion_level)
    WHERE congestion_level IN ('HEAVY', 'STANDSTILL');

-- R10 incidents on one day (after rewriting DATE(reported_at) as a range).
CREATE INDEX idx_incidents_reported
    ON incident_reports (reported_at)
    INCLUDE (report_id, segment_id, incident_type, expires_at, upvotes);

-- W05 deletes expired incidents. Costs a little on every insert (see write-overhead section).
CREATE INDEX idx_incidents_expires
    ON incident_reports (expires_at);

-- R11 ETA quality: only COMPLETED trips, range on started_at, covered aggregate columns.
CREATE INDEX idx_nav_completed_started
    ON navigation_sessions (started_at)
    INCLUDE (travel_mode, eta_minutes, actual_minutes)
    WHERE status = 'COMPLETED';

-- R12 and R20: range scans over time. BRIN is small because rows are stored in time order.
CREATE INDEX idx_nav_started_brin
    ON navigation_sessions USING brin (started_at);

-- R16, R17, R19: all navigations to one destination, optionally in a date range.
CREATE INDEX idx_nav_dest_started
    ON navigation_sessions (dest_place_id, started_at)
    INCLUDE (rerouted_count, status);

-- R13 anti-join: only non-NULL origins are indexed (partial), since NULL origins never match.
CREATE INDEX idx_nav_origin
    ON navigation_sessions (origin_place_id)
    WHERE origin_place_id IS NOT NULL;

-- R24 duplicate listings: match on name, then a latitude range.
CREATE INDEX idx_places_name_lat
    ON places (name, latitude)
    INCLUDE (place_id, longitude, city_id, category_id);

-- R23 Plus Code lookup is covered by the UNIQUE constraint on places.plus_code (from 01_schema.sql).
-- W02 ON CONFLICT (place_id, user_id) needs the UNIQUE constraint on place_reviews from 01_schema.sql.

ANALYZE;