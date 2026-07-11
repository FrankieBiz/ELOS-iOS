import { Router, Request, Response } from "express";
import * as profileService from "../services/profileService";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { upsertProfileSchema, usernameSchema } from "../schemas";
import { qs } from "../lib/query";

const router = Router();

router.get("/", requireAuth, async (req: Request, res: Response) => {
  // Lazy backfill: guarantee every user has a username (so they're findable),
  // including legacy accounts created before usernames existed. No-op if set.
  await profileService.ensureUsername(req.user!.id);
  let profile = await profileService.getProfile(req.user!.id);
  if (!profile) {
    // A missing row means signup-time provisioning didn't run (trigger failure,
    // pre-trigger account, race). Create it here so a new user's first fetch
    // never 404s and onboarding can proceed.
    profile = await profileService.upsertProfile(req.user!.id, {});
  }
  res.json(profile);
});

// Live availability check for the username field (advisory; the unique-constraint
// 409 on PATCH is the authoritative guard against races).
router.get("/username-available", requireAuth, async (req: Request, res: Response) => {
  const parsed = usernameSchema.safeParse(qs(req.query.u));
  if (!parsed.success) {
    res.json({ available: false, reason: "invalid" });
    return;
  }
  const available = await profileService.usernameAvailable(parsed.data, req.user!.id);
  res.json({ available });
});

router.patch("/", requireAuth, validateBody(upsertProfileSchema), async (req: Request, res: Response) => {
  const profile = await profileService.upsertProfile(
    req.user!.id,
    req.body as profileService.ProfileFields
  );
  res.json(profile);
});

export default router;
