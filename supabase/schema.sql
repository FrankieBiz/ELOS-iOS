-- Run this in the Supabase SQL Editor after creating your project.
-- Supabase manages auth.users automatically.

-- ─────────────────────────────────────────────
-- Profiles table
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  user_id             UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name          TEXT,
  last_name           TEXT,
  height_cm           DOUBLE PRECISION,
  weight_kg           DOUBLE PRECISION,
  age_years           INTEGER,
  training_experience TEXT        CHECK (training_experience IN ('beginner', 'intermediate', 'advanced')),
  training_goal       TEXT        CHECK (training_goal IN ('strength', 'hypertrophy', 'endurance', 'weight_loss')),
  school_name         TEXT,
  school_year         TEXT        CHECK (school_year IN ('freshman', 'sophomore', 'junior', 'senior')),
  cal_goal            INTEGER,
  protein_goal        INTEGER,
  carb_goal           INTEGER,
  fat_goal            INTEGER,
  onboarding_complete BOOLEAN     NOT NULL DEFAULT false,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────
-- Row-Level Security
-- ─────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read/update only their own profile
CREATE POLICY "Users read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Service role (used by the Express API) has unrestricted access
CREATE POLICY "Service role full access"
  ON public.profiles FOR ALL
  USING (auth.role() = 'service_role');

-- ─────────────────────────────────────────────
-- Auto-create profile row on signup
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();
