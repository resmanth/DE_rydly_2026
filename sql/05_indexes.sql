-- =====================================================================
-- CP3: Optimization Indexes for Google Maps DBMS
-- =====================================================================
SET search_path TO gmaps;

-- 1. Places & Spatial Searches (Speeds up R01, R03, R04, R24)
CREATE INDEX idx_places_lat_lng ON places (latitude, longitude);
CREATE INDEX idx_places_city_cat_rating ON places (city_id, category_id, avg_rating DESC) WHERE NOT is_permanently_closed;
CREATE INDEX idx_places_name ON places (name);
CREATE INDEX idx_places_city_rating ON places (city_id, avg_rating DESC);

-- 2. Reviews (Speeds up R05, R14, R22)
CREATE INDEX idx_reviews_place_date ON place_reviews (place_id, created_at DESC);
CREATE INDEX idx_reviews_created ON place_reviews (created_at DESC);

-- 3. Navigation Sessions (Speeds up R11, R12, R13, R16, R17, R18, R19, R20)
CREATE INDEX idx_nav_dest_started ON navigation_sessions (dest_place_id, started_at);
CREATE INDEX idx_nav_started ON navigation_sessions (started_at);
CREATE INDEX idx_nav_origin ON navigation_sessions (origin_place_id);

-- 4. Traffic & Incidents (Speeds up R07, R08, R09, R10)
CREATE INDEX idx_traffic_segment_date ON traffic_readings (segment_id, recorded_at DESC);
CREATE INDEX idx_traffic_recorded_level ON traffic_readings (recorded_at DESC, congestion_level);
CREATE INDEX idx_incidents_reported ON incident_reports (reported_at DESC);

-- 5. User Saved Places (Speeds up R06)
CREATE INDEX idx_saved_user_date ON saved_places (user_id, list_name, saved_at DESC);