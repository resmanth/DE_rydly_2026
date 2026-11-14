DROP SCHEMA IF EXISTS gmaps CASCADE;
CREATE SCHEMA gmaps;
SET search_path TO gmaps;

CREATE TABLE cities (
    city_id     INTEGER PRIMARY KEY,
    city_name   VARCHAR(50) NOT NULL UNIQUE,
    center_lat  NUMERIC(9,6) NOT NULL CHECK (center_lat BETWEEN -90 AND 90),
    center_lng  NUMERIC(9,6) NOT NULL CHECK (center_lng BETWEEN -180 AND 180)
);

CREATE TABLE place_categories (
    category_id    INTEGER PRIMARY KEY,
    category_name  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE places (
    place_id               INTEGER PRIMARY KEY,
    plus_code              VARCHAR(12) NOT NULL UNIQUE
                           CHECK (plus_code ~ '^[23456789CFGHJMPQRVWX]{8}\+[23456789CFGHJMPQRVWX]{2,3}$'),
    name                   VARCHAR(100) NOT NULL,
    category_id            INTEGER NOT NULL REFERENCES place_categories(category_id) ON DELETE RESTRICT,
    city_id                INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    latitude               NUMERIC(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude              NUMERIC(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    address                VARCHAR(200) NOT NULL,
    phone                  VARCHAR(15) UNIQUE,
    website                VARCHAR(200) UNIQUE,
    price_level            SMALLINT CHECK (price_level BETWEEN 1 AND 4),
    avg_rating             NUMERIC(2,1) CHECK (avg_rating BETWEEN 1 AND 5),
    review_count           INTEGER NOT NULL DEFAULT 0 CHECK (review_count >= 0),
    is_permanently_closed  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMPTZ NOT NULL
);

CREATE TABLE opening_hours (
    place_id  INTEGER NOT NULL REFERENCES places(place_id) ON DELETE CASCADE,
    weekday   SMALLINT NOT NULL CHECK (weekday BETWEEN 1 AND 7),
    opens     TIME NOT NULL,
    closes    TIME NOT NULL,
    PRIMARY KEY (place_id, weekday),
    CHECK (opens <> closes)
);

CREATE TABLE users (
    user_id        INTEGER PRIMARY KEY,
    display_name   VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    home_city_id   INTEGER REFERENCES cities(city_id) ON DELETE SET NULL,
    is_local_guide BOOLEAN NOT NULL DEFAULT FALSE,
    guide_level    SMALLINT CHECK (guide_level BETWEEN 1 AND 10),
    created_at     TIMESTAMPTZ NOT NULL,
    CHECK ((is_local_guide AND guide_level IS NOT NULL) OR (NOT is_local_guide AND guide_level IS NULL))
);

CREATE TABLE place_reviews (
    review_id    INTEGER PRIMARY KEY,
    place_id     INTEGER NOT NULL REFERENCES places(place_id) ON DELETE CASCADE,
    user_id      INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text  VARCHAR(500),
    photo_count  SMALLINT NOT NULL DEFAULT 0 CHECK (photo_count >= 0),
    created_at   TIMESTAMPTZ NOT NULL,
    UNIQUE (place_id, user_id)
);

CREATE TABLE saved_places (
    user_id    INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    place_id   INTEGER NOT NULL REFERENCES places(place_id) ON DELETE CASCADE,
    list_name  VARCHAR(30) NOT NULL CHECK (list_name IN ('Favourites', 'Starred', 'Travel plans', 'Want to go')),
    saved_at   TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (user_id, place_id, list_name)
);

CREATE TABLE road_segments (
    segment_id        INTEGER PRIMARY KEY,
    road_name         VARCHAR(100) NOT NULL,
    city_id           INTEGER NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    road_type         VARCHAR(10) NOT NULL CHECK (road_type IN ('HIGHWAY', 'ARTERIAL', 'LOCAL')),
    start_lat         NUMERIC(9,6) NOT NULL CHECK (start_lat BETWEEN -90 AND 90),
    start_lng         NUMERIC(9,6) NOT NULL CHECK (start_lng BETWEEN -180 AND 180),
    end_lat           NUMERIC(9,6) NOT NULL CHECK (end_lat BETWEEN -90 AND 90),
    end_lng           NUMERIC(9,6) NOT NULL CHECK (end_lng BETWEEN -180 AND 180),
    length_m          INTEGER NOT NULL CHECK (length_m > 0),
    speed_limit_kmph  SMALLINT NOT NULL CHECK (speed_limit_kmph > 0)
);

CREATE TABLE traffic_readings (
    reading_id        INTEGER PRIMARY KEY,
    segment_id        INTEGER NOT NULL REFERENCES road_segments(segment_id) ON DELETE CASCADE,
    recorded_at       TIMESTAMPTZ NOT NULL,
    avg_speed_kmph    NUMERIC(5,1) NOT NULL CHECK (avg_speed_kmph >= 0),
    congestion_level  VARCHAR(10) NOT NULL CHECK (congestion_level IN ('LOW', 'MODERATE', 'HEAVY', 'STANDSTILL'))
);

CREATE TABLE navigation_sessions (
    session_id        INTEGER PRIMARY KEY,
    user_id           INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    origin_place_id   INTEGER REFERENCES places(place_id) ON DELETE SET NULL,
    origin_lat        NUMERIC(9,6) NOT NULL CHECK (origin_lat BETWEEN -90 AND 90),
    origin_lng        NUMERIC(9,6) NOT NULL CHECK (origin_lng BETWEEN -180 AND 180),
    dest_place_id     INTEGER NOT NULL REFERENCES places(place_id) ON DELETE RESTRICT,
    travel_mode       VARCHAR(12) NOT NULL CHECK (travel_mode IN ('DRIVE', 'TWO_WHEELER', 'WALK', 'TRANSIT')),
    started_at        TIMESTAMPTZ NOT NULL,
    distance_km       NUMERIC(6,2) NOT NULL CHECK (distance_km > 0),
    eta_minutes       INTEGER NOT NULL CHECK (eta_minutes > 0),
    actual_minutes    INTEGER CHECK (actual_minutes > 0),
    rerouted_count    SMALLINT NOT NULL DEFAULT 0 CHECK (rerouted_count >= 0),
    status            VARCHAR(12) NOT NULL CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    CHECK ((status = 'COMPLETED') = (actual_minutes IS NOT NULL))
);

CREATE TABLE incident_reports (
    report_id      INTEGER PRIMARY KEY,
    segment_id     INTEGER NOT NULL REFERENCES road_segments(segment_id) ON DELETE CASCADE,
    user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    incident_type  VARCHAR(15) NOT NULL CHECK (incident_type IN ('ACCIDENT', 'BREAKDOWN', 'CLOSURE', 'POLICE', 'ROADWORK', 'WATERLOGGING')),
    reported_at    TIMESTAMPTZ NOT NULL,
    expires_at     TIMESTAMPTZ NOT NULL,
    upvotes        INTEGER NOT NULL DEFAULT 0 CHECK (upvotes >= 0),
    CHECK (expires_at > reported_at)
);