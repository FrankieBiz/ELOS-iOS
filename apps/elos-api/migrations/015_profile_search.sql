ALTER TABLE profiles ADD COLUMN IF NOT EXISTS search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english',
      coalesce(first_name, '') || ' ' ||
      coalesce(last_name,  '') || ' ' ||
      coalesce(username,   ''))
  ) STORED;

CREATE INDEX IF NOT EXISTS profiles_search_idx ON profiles USING GIN(search_vector);
