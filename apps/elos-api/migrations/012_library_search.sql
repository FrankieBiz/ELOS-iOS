ALTER TABLE creators ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(name,'') || ' ' || coalesce(bio,'') || ' ' || coalesce(training_style,''))
  ) STORED;
CREATE INDEX creators_search_idx ON creators USING GIN(search_vector);

-- alternate_names omitted from GENERATED column (array_to_string is STABLE not IMMUTABLE in PG16)
ALTER TABLE machines ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(name,'') || ' ' || coalesce(description,''))
  ) STORED;
CREATE INDEX machines_search_idx ON machines USING GIN(search_vector);

ALTER TABLE creator_workouts ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,'') || ' ' || coalesce(goal,''))
  ) STORED;
CREATE INDEX creator_workouts_search_idx ON creator_workouts USING GIN(search_vector);
