-- =====================================================================
-- Google Maps DBMS Project: Optimized Workload
-- Phase 4: Contains rewritten queries for better SARGability and Joins
-- =====================================================================
SET search_path TO gmaps;
BEGIN;

-- @R01
SELECT place_id, name, avg_rating,
       round((6371 * acos(least(1, cos(radians(12.9352)) * cos(radians(latitude)) * cos(radians(longitude) - radians(77.6245))
                                  + sin(radians(12.9352)) * sin(radians(latitude)))))::numeric, 3) AS km
FROM places
WHERE category_id = 1
  AND NOT is_permanently_closed
  AND latitude  BETWEEN 12.9352 - 0.009 AND 12.9352 + 0.009
  AND longitude BETWEEN 77.6245 - 0.0093 AND 77.6245 + 0.0093
ORDER BY km
LIMIT 20;

-- @R02
SELECT p.place_id, p.name, p.address, p.phone, p.avg_rating, p.review_count, h.opens, h.closes
FROM places p
LEFT JOIN opening_hours h ON h.place_id = p.place_id AND h.weekday = 2
WHERE p.place_id = 18;

-- @R03
SELECT place_id, name, avg_rating, review_count
FROM places
WHERE city_id = 1 AND name ILIKE '%biryani%'
ORDER BY avg_rating DESC NULLS LAST, review_count DESC
LIMIT 20;

-- @R04
SELECT p.place_id, p.name, h.opens, h.closes
FROM places p
JOIN opening_hours h ON h.place_id = p.place_id AND h.weekday = 6
WHERE p.city_id = 1 AND p.category_id = 1 AND NOT p.is_permanently_closed
  AND (   (h.opens < h.closes AND TIME '23:30' BETWEEN h.opens AND h.closes)
       OR (h.opens > h.closes AND (TIME '23:30' >= h.opens OR TIME '23:30' < h.closes)))
ORDER BY p.avg_rating DESC NULLS LAST
LIMIT 30;

-- @R05
SELECT r.review_id, u.display_name, u.is_local_guide, r.rating, r.review_text, r.photo_count, r.created_at
FROM place_reviews r
JOIN users u ON u.user_id = r.user_id
WHERE r.place_id = 18
ORDER BY r.created_at DESC
LIMIT 10;

-- @R06
SELECT s.list_name, p.place_id, p.name, s.saved_at
FROM saved_places s
JOIN places p ON p.place_id = s.place_id
WHERE s.user_id = 1005
ORDER BY s.list_name, s.saved_at DESC;

-- @R07
SELECT DISTINCT ON (t.segment_id) t.segment_id, s.road_name, t.recorded_at, t.avg_speed_kmph, t.congestion_level
FROM traffic_readings t
JOIN road_segments s ON s.segment_id = t.segment_id
WHERE s.city_id = 1 AND s.road_name LIKE 'Outer Ring Road%'
ORDER BY t.segment_id, t.recorded_at DESC;

-- @R08
SELECT s.segment_id, s.road_name, t.recorded_at, t.avg_speed_kmph, t.congestion_level
FROM traffic_readings t
JOIN road_segments s ON s.segment_id = t.segment_id
WHERE s.city_id = 1
  AND t.congestion_level IN ('HEAVY', 'STANDSTILL')
  AND t.recorded_at >= '2026-06-30 18:00:00+05:30'
ORDER BY t.recorded_at DESC;

-- @R09
SELECT EXTRACT(HOUR FROM recorded_at) AS hour, round(avg(avg_speed_kmph), 1) AS avg_speed, count(*) AS readings
FROM traffic_readings
WHERE segment_id = 5
GROUP BY 1
ORDER BY 1;

-- @R10
-- OPTIMIZED: Removed DATE() function wrap on i.reported_at to allow index seeking
SELECT i.report_id, i.incident_type, s.road_name, i.reported_at, i.expires_at, i.upvotes
FROM incident_reports i
JOIN road_segments s ON s.segment_id = i.segment_id
WHERE s.city_id = 1
  AND i.reported_at >= '2026-06-30 00:00:00+05:30'
  AND i.reported_at < '2026-07-01 00:00:00+05:30'
ORDER BY i.reported_at DESC;

-- @R11
-- OPTIMIZED: Removed EXTRACT() function wrap to allow index seeking on started_at
SELECT date_trunc('month', started_at) AS month, travel_mode,
       round(avg(actual_minutes - eta_minutes), 2) AS avg_error_min, count(*) AS trips
FROM navigation_sessions
WHERE status = 'COMPLETED'
  AND started_at >= '2026-01-01 00:00:00+05:30'
  AND started_at < '2027-01-01 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R12
SELECT p.place_id, p.name, count(*) AS navigations
FROM navigation_sessions n
JOIN places p ON p.place_id = n.dest_place_id
WHERE p.city_id = 2
  AND n.started_at >= '2026-06-24'
GROUP BY p.place_id, p.name
ORDER BY navigations DESC
LIMIT 10;

-- @R13
-- OPTIMIZED: Replaced NOT IN with NOT EXISTS for better query planner execution
SELECT p.place_id, p.name
FROM places p
WHERE NOT EXISTS (
    SELECT 1 FROM navigation_sessions n WHERE n.origin_place_id = p.place_id
);

-- @R14
SELECT u.user_id, u.display_name, u.guide_level, count(*) AS reviews, sum(r.photo_count) AS photos
FROM place_reviews r
JOIN users u ON u.user_id = r.user_id
WHERE r.created_at >= '2026-01-01'
GROUP BY u.user_id, u.display_name, u.guide_level
ORDER BY reviews DESC, photos DESC
LIMIT 20;

-- @R15
SELECT p.place_id, p.avg_rating, p.review_count, round(avg(r.rating), 1) AS actual_rating, count(*) AS actual_reviews
FROM places p
JOIN place_reviews r ON r.place_id = p.place_id
GROUP BY p.place_id, p.avg_rating, p.review_count
HAVING p.review_count <> count(*) OR p.avg_rating <> round(avg(r.rating), 1)
ORDER BY p.place_id;

-- @R16
SELECT p.place_id, p.name, count(*) AS navigations_2026
FROM places p
JOIN navigation_sessions n ON n.dest_place_id = p.place_id
WHERE p.is_permanently_closed
  AND n.started_at >= '2026-01-01'
GROUP BY p.place_id, p.name
ORDER BY navigations_2026 DESC;

-- @R17
SELECT dest_place_id, count(*) AS trips, round(avg(rerouted_count), 2) AS avg_reroutes
FROM navigation_sessions
GROUP BY dest_place_id
HAVING count(*) >= 5
ORDER BY avg_reroutes DESC
LIMIT 20;

-- @R18
SELECT travel_mode, count(*) AS sessions,
       round(100.0 * count(*) FILTER (WHERE status = 'CANCELLED') / count(*), 1) AS cancelled_pct
FROM navigation_sessions
GROUP BY travel_mode
ORDER BY cancelled_pct DESC;

-- @R19
-- OPTIMIZED: Removed correlated subqueries in SELECT clause in favor of a LEFT JOIN structure
SELECT p.place_id, p.name,
       count(n.session_id) AS navigations,
       max(n.started_at) AS last_navigation_at
FROM places p
JOIN place_categories c ON c.category_id = p.category_id
LEFT JOIN navigation_sessions n ON n.dest_place_id = p.place_id
WHERE c.category_name = 'Hospital' AND p.city_id = 1
GROUP BY p.place_id, p.name
ORDER BY navigations DESC;

-- @R20
-- OPTIMIZED: Changed WHERE clause casting to strict timestamp boundaries
SELECT day, sessions, sum(sessions) OVER (ORDER BY day) AS running_total
FROM (
    SELECT started_at::date AS day, count(*) AS sessions
    FROM navigation_sessions
    WHERE started_at >= '2026-06-01 00:00:00+05:30' 
      AND started_at < '2026-07-01 00:00:00+05:30'
    GROUP BY 1
) d
ORDER BY day;

-- @R21
SELECT c.category_name, count(*) AS places_without_hours
FROM places p
JOIN place_categories c ON c.category_id = p.category_id
WHERE NOT EXISTS (SELECT 1 FROM opening_hours h WHERE h.place_id = p.place_id)
GROUP BY c.category_name
ORDER BY places_without_hours DESC;

-- @R22
SELECT review_id, place_id, user_id, rating, created_at
FROM place_reviews
ORDER BY created_at DESC
OFFSET 50000
LIMIT 25;

-- @R23
SELECT place_id, name, latitude, longitude
FROM places
WHERE plus_code = '22222222+2W';

-- @R24
SELECT a.place_id, b.place_id AS duplicate_id, a.name
FROM places a
JOIN places b ON b.name = a.name AND b.place_id > a.place_id
             AND abs(b.latitude - a.latitude) < 0.001 AND abs(b.longitude - a.longitude) < 0.001
WHERE a.city_id = 1 AND a.category_id = 1;

-- @R25
SELECT s.road_type, count(*) AS readings,
       round(100.0 * count(*) FILTER (WHERE t.avg_speed_kmph > s.speed_limit_kmph) / count(*), 1) AS over_limit_pct
FROM traffic_readings t
JOIN road_segments s ON s.segment_id = t.segment_id
GROUP BY s.road_type
ORDER BY over_limit_pct DESC;

-- @W01
INSERT INTO navigation_sessions (session_id, user_id, origin_lat, origin_lng, dest_place_id, travel_mode,
                                 started_at, distance_km, eta_minutes, status)
VALUES (90000001, 1005, 12.935200, 77.624500, 18, 'TWO_WHEELER', '2026-07-01 20:00:00+05:30', 4.20, 14, 'IN_PROGRESS');

-- @W02
INSERT INTO place_reviews (review_id, place_id, user_id, rating, review_text, photo_count, created_at)
VALUES (90000001, 18, 1005, 4, 'Good food, slow service', 2, '2026-07-01 21:00:00+05:30')
ON CONFLICT (place_id, user_id) DO NOTHING;

-- @W03
INSERT INTO saved_places (user_id, place_id, list_name, saved_at)
VALUES (1005, 18, 'Want to go', '2026-07-01 21:05:00+05:30')
ON CONFLICT DO NOTHING;

-- @W04
UPDATE places p
SET avg_rating = s.avg_rating, review_count = s.n
FROM (SELECT place_id, round(avg(rating), 1) AS avg_rating, count(*) AS n FROM place_reviews GROUP BY place_id) s
WHERE s.place_id = p.place_id
  AND (p.avg_rating IS DISTINCT FROM s.avg_rating OR p.review_count <> s.n);

-- @W05
DELETE FROM incident_reports
WHERE expires_at < '2026-06-01';

-- @END
ROLLBACK;