import { Router, Request, Response } from "express";
import * as profileService from "../services/profileService";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { upsertProfileSchema } from "../schemas";

const router = Router();

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const profile = await profileService.getProfile(req.user!.id);
  if (!profile) {
    res.status(404).json({ error: "Profile not found" });
    return;
  }
  res.json(profile);
});

router.patch("/", requireAuth, validateBody(upsertProfileSchema), async (req: Request, res: Response) => {
  const profile = await profileService.upsertProfile(
    req.user!.id,
    req.body as profileService.ProfileFields
  );
  res.json(profile);
});

export default router;
