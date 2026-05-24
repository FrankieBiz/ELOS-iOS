import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { ReadinessService } from "../services/readinessService";
import { pool } from "../db";
import { createReadinessSchema } from "../schemas";

const router = Router();
const service = new ReadinessService(pool);

router.post("/", requireAuth, validateBody(createReadinessSchema), async (req: Request, res: Response) => {
  const checkin = await service.logCheckin(req.user!.id, req.body);
  res.status(201).json(checkin);
});

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const days = Math.min(Number(req.query.days ?? 30), 365);
  const history = await service.getHistory(req.user!.id, days);
  res.json({ checkins: history });
});

router.get("/today", requireAuth, async (req: Request, res: Response) => {
  const checkin = await service.getTodayCheckin(req.user!.id);
  if (!checkin) { res.status(404).json({ error: "No check-in today" }); return; }
  res.json(checkin);
});

export default router;
