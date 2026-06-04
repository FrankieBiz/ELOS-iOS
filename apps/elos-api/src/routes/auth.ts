import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import * as profileService from "../services/profileService";
import { pool } from "../db";
import { supabaseAdmin } from "../supabase";

const router = Router();

// Supabase handles /auth/register and /auth/login on the client side.
// This endpoint lets the app check session state and onboarding status.
router.get("/me", requireAuth, async (req: Request, res: Response) => {
  try {
    const profile = await profileService.getProfile(req.user!.id);
    res.json({
      user_id: req.user!.id,
      email: req.user!.email,
      onboarding_complete: profile?.onboarding_complete ?? false,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    res.status(500).json({ error: msg });
  }
});

router.delete("/account", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  try {
    await pool.query(
      `DELETE FROM workout_sessions WHERE user_id = $1`,
      [userId],
    );
    await pool.query(
      `DELETE FROM workout_templates WHERE user_id = $1`,
      [userId],
    );
    await pool.query(
      `DELETE FROM exercise_definitions WHERE owner_id = $1`,
      [userId],
    );
    await pool.query(
      `DELETE FROM readiness_checkins WHERE user_id = $1`,
      [userId],
    );
    await pool.query(
      `DELETE FROM user_split_days WHERE split_id IN (SELECT id FROM user_splits WHERE user_id = $1)`,
      [userId],
    );
    await pool.query(`DELETE FROM user_splits WHERE user_id = $1`, [userId]);
    await pool.query(`DELETE FROM profiles WHERE user_id = $1`, [userId]);
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (error) throw error;
    res.json({ ok: true });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    res.status(500).json({ error: msg });
  }
});

export default router;
