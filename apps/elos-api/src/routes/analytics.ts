import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { AnalyticsService } from "../services/analyticsService";
import { pool } from "../db";

const router = Router();
const service = new AnalyticsService(pool);

router.get("/volume", requireAuth, async (req: Request, res: Response) => {
  const weeks = Math.min(Number(req.query.weeks ?? 8), 52);
  const data = await service.getWeeklyVolume(req.user!.id, weeks);
  res.json({ volume: data });
});

router.get("/e1rm/:name", requireAuth, async (req: Request, res: Response) => {
  const weeks = Math.min(Number(req.query.weeks ?? 12), 52);
  const data = await service.getE1RMHistory(req.user!.id, req.params.name as string, weeks);
  res.json({ e1rm: data });
});

router.get("/prs", requireAuth, async (req: Request, res: Response) => {
  const prs = await service.getPersonalRecords(req.user!.id);
  res.json({ prs });
});

router.get("/suggest/:name", requireAuth, async (req: Request, res: Response) => {
  const suggestion = await service.getOverloadSuggestion(req.user!.id, req.params.name as string);
  res.json(suggestion);
});

export default router;
