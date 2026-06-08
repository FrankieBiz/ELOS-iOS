-- Defense-in-depth: enable Row Level Security on all user-data tables so the public
-- anon key (PostgREST) cannot read/write them directly. The Express API connects as
-- the table owner (raw pg Pool) and via the Supabase service role, both of which
-- BYPASS RLS, so server access is unaffected. With RLS enabled and NO permissive
-- policies, anon/authenticated PostgREST access is denied by default.

ALTER TABLE IF EXISTS profiles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS workout_sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS exercise_sets           ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS workout_templates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS template_exercises      ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS exercise_definitions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS readiness_checkins      ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_splits             ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_split_days         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS friendships             ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS saved_library_workouts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_favorite_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_reports            ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ai_briefs               ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS feed_posts              ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS post_reactions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_blocks             ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS workouts                ENABLE ROW LEVEL SECURITY;
