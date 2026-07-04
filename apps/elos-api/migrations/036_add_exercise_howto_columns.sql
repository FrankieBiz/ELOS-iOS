-- Add how-to content to exercise_definitions.
-- instructions: ordered step strings (English), '{}' when none.
-- image_key: reference to a bundled demo photo in the iOS asset catalog; NULL when none.
-- Content attaches to the GENERIC exercise, so every brand-machine variant inherits it.
ALTER TABLE exercise_definitions
  ADD COLUMN IF NOT EXISTS instructions TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS image_key    TEXT;
