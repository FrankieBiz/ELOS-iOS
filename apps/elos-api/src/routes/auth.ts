import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import * as profileService from "../services/profileService";

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

export default router;
