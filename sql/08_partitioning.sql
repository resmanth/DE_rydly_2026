
-- ============================================================
-- CP4: Monthly RANGE partitioning for navigation_sessions
-- Partition key: started_at
-- Data range: January 2025 - June 2026
-- PostgreSQL 18
-- ============================================================

BEGIN;

SET search_path TO gmaps;

-- Keep the original table temporarily during migration.
ALTER TABLE gmaps.navigation_sessions
RENAME TO navigation_sessions_unpartitioned;

-- Create the new partitioned parent table.
-- PostgreSQL requires the partition key in the primary key.
CREATE TABLE gmaps.navigation_sessions_partitioned (
    session_id        INTEGER NOT NULL,
    user_id           INTEGER REFERENCES gmaps.users(user_id) ON DELETE SET NULL,
    origin_place_id   INTEGER REFERENCES gmaps.places(place_id) ON DELETE SET NULL,
    origin_lat        NUMERIC(9,6) NOT NULL CHECK (origin_lat BETWEEN -90 AND 90),
    origin_lng        NUMERIC(9,6) NOT NULL CHECK (origin_lng BETWEEN -180 AND 180),
    dest_place_id     INTEGER NOT NULL REFERENCES gmaps.places(place_id) ON DELETE RESTRICT,
    travel_mode       VARCHAR(12) NOT NULL CHECK (travel_mode IN ('DRIVE', 'TWO_WHEELER', 'WALK', 'TRANSIT')),
    started_at        TIMESTAMPTZ NOT NULL,
    distance_km       NUMERIC(6,2) NOT NULL CHECK (distance_km > 0),
    eta_minutes       INTEGER NOT NULL CHECK (eta_minutes > 0),
    actual_minutes    INTEGER CHECK (actual_minutes > 0),
    rerouted_count    SMALLINT NOT NULL DEFAULT 0 CHECK (rerouted_count >= 0),
    status            VARCHAR(12) NOT NULL CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'CANCELLED')),

    PRIMARY KEY (session_id, started_at),

    CHECK ((status = 'COMPLETED') = (actual_minutes IS NOT NULL))
)
PARTITION BY RANGE (started_at);

-- Create one partition per month, using India local-time boundaries.
DO $$
DECLARE
    month_start DATE := DATE '2025-01-01';
    month_end   DATE;
    partition_name TEXT;
BEGIN
    WHILE month_start < DATE '2026-07-01' LOOP
        month_end := (month_start + INTERVAL '1 month')::DATE;
        partition_name := 'navigation_sessions_p' || TO_CHAR(month_start, 'YYYYMM');

        EXECUTE FORMAT(
            'CREATE TABLE gmaps.%I PARTITION OF gmaps.navigation_sessions_partitioned
             FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            month_start::TIMESTAMP AT TIME ZONE 'Asia/Kolkata',
            month_end::TIMESTAMP AT TIME ZONE 'Asia/Kolkata'
        );

        month_start := month_end;
    END LOOP;
END $$;

-- Catch dates outside the explicitly created monthly partitions.
CREATE TABLE gmaps.navigation_sessions_p_default
PARTITION OF gmaps.navigation_sessions_partitioned DEFAULT;

-- Copy the existing 4 million rows.
INSERT INTO gmaps.navigation_sessions_partitioned
SELECT *
FROM gmaps.navigation_sessions_unpartitioned;

-- Verify that no rows were lost during migration.
DO $$
DECLARE
    old_count BIGINT;
    new_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO old_count
    FROM gmaps.navigation_sessions_unpartitioned;

    SELECT COUNT(*) INTO new_count
    FROM gmaps.navigation_sessions_partitioned;

    IF old_count <> new_count THEN
        RAISE EXCEPTION
            'Partition migration failed: old rows %, new rows %',
            old_count, new_count;
    END IF;

    RAISE NOTICE 'Migration verified: % rows copied', new_count;
END $$;

-- Replace the original table.
DROP TABLE gmaps.navigation_sessions_unpartitioned;

ALTER TABLE gmaps.navigation_sessions_partitioned
RENAME TO navigation_sessions;

-- Recreate CP3 navigation indexes on the partitioned parent.
CREATE INDEX idx_nav_completed_started
    ON gmaps.navigation_sessions (started_at)
    INCLUDE (travel_mode, eta_minutes, actual_minutes)
    WHERE status = 'COMPLETED';

CREATE INDEX idx_nav_started_brin
    ON gmaps.navigation_sessions USING BRIN (started_at);

CREATE INDEX idx_nav_dest_started
    ON gmaps.navigation_sessions (dest_place_id, started_at)
    INCLUDE (rerouted_count, status);

CREATE INDEX idx_nav_origin
    ON gmaps.navigation_sessions (origin_place_id)
    WHERE origin_place_id IS NOT NULL;

ANALYZE gmaps.navigation_sessions;

COMMIT;
