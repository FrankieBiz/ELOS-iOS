CREATE TABLE machine_brands (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  slug        TEXT UNIQUE NOT NULL,
  description TEXT,
  website_url TEXT
);

CREATE TABLE machines (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  slug              TEXT UNIQUE NOT NULL,
  alternate_names   TEXT[] DEFAULT '{}',
  category          TEXT NOT NULL,
  sub_category      TEXT,
  equipment_type    TEXT NOT NULL,
  primary_muscles   TEXT[] NOT NULL,
  secondary_muscles TEXT[] DEFAULT '{}',
  movement_pattern  TEXT,
  description       TEXT,
  image_url         TEXT,
  tags              TEXT[] DEFAULT '{}',
  review_status     TEXT DEFAULT 'pending',
  created_at        TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX machines_category_idx  ON machines(category);
CREATE INDEX machines_equipment_idx ON machines(equipment_type);

CREATE TABLE machine_models (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id         UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
  brand_id           UUID NOT NULL REFERENCES machine_brands(id),
  model_name         TEXT,
  equipment_type     TEXT,
  image_url          TEXT,
  setup_instructions TEXT,
  adjustment_notes   TEXT,
  usage_steps        TEXT[] DEFAULT '{}',
  form_cues          TEXT[] DEFAULT '{}',
  common_mistakes    TEXT[] DEFAULT '{}',
  safety_notes       TEXT[] DEFAULT '{}',
  beginner_tips      TEXT[] DEFAULT '{}',
  advanced_tips      TEXT[] DEFAULT '{}',
  rep_range_rec      TEXT,
  notes              TEXT,
  review_status      TEXT DEFAULT 'pending',
  created_at         TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX machine_models_machine_idx ON machine_models(machine_id);
CREATE INDEX machine_models_brand_idx   ON machine_models(brand_id);
