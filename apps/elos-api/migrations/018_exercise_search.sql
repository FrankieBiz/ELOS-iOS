-- Full-text search on exercise_definitions, mirroring the pattern used by machines.search_vector.

ALTER TABLE exercise_definitions
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'english',
      coalesce(name, '') || ' ' ||
      coalesce(primary_muscle, '') || ' ' ||
      coalesce(equipment, '') || ' ' ||
      coalesce(movement_pattern, '')
    )
  ) STORED;

CREATE INDEX exercise_definitions_search_idx
  ON exercise_definitions
  USING GIN (search_vector);
