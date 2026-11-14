SET search_path TO gmaps;

\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy place_categories FROM 'seed_data/place_categories.csv' WITH (FORMAT csv, HEADER true)
\copy places FROM 'seed_data/places.csv' WITH (FORMAT csv, HEADER true)
\copy opening_hours FROM 'seed_data/opening_hours.csv' WITH (FORMAT csv, HEADER true)
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy place_reviews FROM 'seed_data/place_reviews.csv' WITH (FORMAT csv, HEADER true)
\copy saved_places FROM 'seed_data/saved_places.csv' WITH (FORMAT csv, HEADER true)
\copy road_segments FROM 'seed_data/road_segments.csv' WITH (FORMAT csv, HEADER true)
\copy traffic_readings FROM 'seed_data/traffic_readings.csv' WITH (FORMAT csv, HEADER true)
\copy navigation_sessions FROM 'seed_data/navigation_sessions.csv' WITH (FORMAT csv, HEADER true)
\copy incident_reports FROM 'seed_data/incident_reports.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;