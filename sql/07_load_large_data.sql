SET search_path TO gmaps;

\copy cities FROM 'large_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy place_categories FROM 'large_data/place_categories.csv' WITH (FORMAT csv, HEADER true)
\copy places FROM 'large_data/places.csv' WITH (FORMAT csv, HEADER true)
\copy opening_hours FROM 'large_data/opening_hours.csv' WITH (FORMAT csv, HEADER true)
\copy users FROM 'large_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy place_reviews FROM 'large_data/place_reviews.csv' WITH (FORMAT csv, HEADER true)
\copy saved_places FROM 'large_data/saved_places.csv' WITH (FORMAT csv, HEADER true)
\copy road_segments FROM 'large_data/road_segments.csv' WITH (FORMAT csv, HEADER true)
\copy traffic_readings FROM 'large_data/traffic_readings.csv' WITH (FORMAT csv, HEADER true)
\copy navigation_sessions FROM 'large_data/navigation_sessions.csv' WITH (FORMAT csv, HEADER true)
\copy incident_reports FROM 'large_data/incident_reports.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;
