import { Pool } from "pg";
import { supabaseAdmin } from "../supabase";
import { callDeepSeek, parseMoodAndBrief } from "../lib/deepseek";

export interface ClientSleepContext {
  hours: number;
  quality: number;
}

export interface ClientAssignmentContext {
  name: string;
  subject: string;
  isUrgent: boolean;
  dueIn: string;
}

export interface ClientExamContext {
  subject: string;
  title: string;
  daysUntil: number;
}

export interface BriefClientContext {
  sleep?: ClientSleepContext;
  assignments?: ClientAssignmentContext[];
  exams?: ClientExamContext[];
}

export interface BriefRow {
  id: string;
  date: string;
  brief_text: string;
  mood: string;
  generated_at: string;
}

export class AiService {
  constructor(private readonly db: Pool) {}

  async getBrief(
    userId: string,
    clientCtx: BriefClientContext,
    force: boolean
  ): Promise<BriefRow> {
    // Serve cached row unless force regeneration
    if (!force) {
      const cached = await this.db.query<BriefRow>(
        `SELECT id, date::text, brief_text, mood, generated_at::text
         FROM ai_briefs WHERE user_id = $1 AND date = CURRENT_DATE`,
        [userId]
      );
      if (cached.rows[0]) return cached.rows[0];
    } else {
      await this.db.query(
        `DELETE FROM ai_briefs WHERE user_id = $1 AND date = CURRENT_DATE`,
        [userId]
      );
    }

    // --- Fetch server-side context ---

    // Profile: first name from Supabase profiles table
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("first_name")
      .eq("user_id", userId)
      .maybeSingle();
    const firstName: string = profile?.first_name ?? "Athlete";

    // Today's readiness check-in
    const readinessRes = await this.db.query<{
      sleep_quality: number;
      soreness: number;
      stress: number;
      motivation: number;
      overall_score: number;
    }>(
      `SELECT sleep_quality, soreness, stress, motivation, overall_score::float
       FROM readiness_checkins WHERE user_id = $1 AND log_date = CURRENT_DATE`,
      [userId]
    );
    const readiness = readinessRes.rows[0] ?? null;

    // Last 7 days of completed workout sessions
    const sessionsRes = await this.db.query<{
      count: string;
      total_volume: string;
      avg_rpe: string;
    }>(
      `SELECT COUNT(*)::text AS count,
              COALESCE(SUM(total_volume), 0)::text AS total_volume,
              COALESCE(AVG(session_rpe), 0)::float::text AS avg_rpe
       FROM workout_sessions
       WHERE user_id = $1
         AND started_at >= NOW() - INTERVAL '7 days'
         AND finished_at IS NOT NULL`,
      [userId]
    );
    const sessions = sessionsRes.rows[0];

    // Active split name
    const splitRes = await this.db.query<{ name: string }>(
      `SELECT name FROM user_splits WHERE user_id = $1 AND is_active = true LIMIT 1`,
      [userId]
    );
    const splitName = splitRes.rows[0]?.name ?? null;

    // --- Build prompt ---
    const prompt = buildPrompt({
      firstName,
      readiness,
      sessions: {
        count: parseInt(sessions.count, 10),
        totalVolume: parseFloat(sessions.total_volume),
        avgRpe: parseFloat(sessions.avg_rpe),
      },
      splitName,
      clientCtx,
    });

    // --- Call DeepSeek + parse ---
    const raw = await callDeepSeek(prompt);
    const { briefText, mood } = parseMoodAndBrief(raw);

    // --- Persist (upsert in case of race) ---
    const insertRes = await this.db.query<BriefRow>(
      `INSERT INTO ai_briefs (user_id, date, brief_text, mood)
       VALUES ($1, CURRENT_DATE, $2, $3)
       ON CONFLICT (user_id, date) DO UPDATE
         SET brief_text    = EXCLUDED.brief_text,
             mood          = EXCLUDED.mood,
             generated_at  = now()
       RETURNING id, date::text, brief_text, mood, generated_at::text`,
      [userId, briefText, mood]
    );
    return insertRes.rows[0];
  }
}

interface PromptContext {
  firstName: string;
  readiness: {
    sleep_quality: number;
    soreness: number;
    stress: number;
    motivation: number;
    overall_score: number;
  } | null;
  sessions: { count: number; totalVolume: number; avgRpe: number };
  splitName: string | null;
  clientCtx: BriefClientContext;
}

function buildPrompt(ctx: PromptContext): string {
  const { firstName, readiness, sessions, splitName, clientCtx } = ctx;

  const sleepLine = clientCtx.sleep
    ? `Sleep last night: ${clientCtx.sleep.hours}h, quality ${clientCtx.sleep.quality}/5`
    : "Sleep last night: no data";

  const readinessLine = readiness
    ? `Readiness check-in: ${readiness.overall_score.toFixed(1)}/5 — sleep ${readiness.sleep_quality}, soreness ${readiness.soreness}, stress ${readiness.stress}, motivation ${readiness.motivation}`
    : "Readiness check-in: No check-in logged yet";

  const splitLine = splitName
    ? `Today's planned workout: current split is "${splitName}"`
    : "Today's planned workout: No active split";

  const sessionLine = `Training this week: ${sessions.count} sessions, ${sessions.totalVolume.toFixed(0)}kg total volume, avg RPE ${sessions.avgRpe.toFixed(1)}`;

  const urgentAssignments = (clientCtx.assignments ?? []).filter((a) => a.isUrgent);
  const deadlineList =
    urgentAssignments.length > 0
      ? urgentAssignments.map((a) => `${a.name} (${a.subject}, due ${a.dueIn})`).join("; ")
      : "None";

  const examList =
    (clientCtx.exams ?? []).length > 0
      ? clientCtx.exams!.map((e) => `${e.title} – ${e.subject} in ${e.daysUntil} day(s)`).join("; ")
      : "None";

  return `You are a concise performance coach for a student-athlete named ${firstName}.

Today's data:
- ${sleepLine}
- ${readinessLine}
- ${splitLine}
- ${sessionLine}
- Upcoming deadlines (48h): ${deadlineList}
- Upcoming exams (7 days): ${examList}

Write exactly 2 sentences. Sentence 1: a direct observation about physical readiness and today's training. Sentence 2: a note about academic or schedule pressure today. Be practical and direct — no fluff, no exclamation points.
On a new final line write: MOOD: positive|cautious|alert`;
}
