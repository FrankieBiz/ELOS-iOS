import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import * as profileService from "../services/profileService";

const router = Router();

// Supabase handles /auth/register and /auth/login on the client side.
// This endpoint lets the app check session state and onboarding status.
// Errors propagate to the central errorHandler (which redacts in production).
router.get("/me", requireAuth, async (req: Request, res: Response) => {
  const profile = await profileService.getProfile(req.user!.id);
  res.json({
    user_id: req.user!.id,
    email: req.user!.email,
    onboarding_complete: profile?.onboarding_complete ?? false,
  });
});

router.delete("/account", requireAuth, async (req: Request, res: Response) => {
  await profileService.deleteAccount(req.user!.id);
  res.json({ ok: true });
});

export default router;
