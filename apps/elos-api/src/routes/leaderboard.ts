import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { LeaderboardService, getWeekStart } from "../services/leaderboardService";
import { pool } from "../db";

const router = Router();
const service = new LeaderboardService(pool);

const qs = (v: unknown): string | undefined => (typeof v === "string" ? v : undefined);

type Metric = "volume" | "sessions" | "streak" | "prs";
const VALID_METRICS: Metric[] = ["volume", "sessions", "streak", "prs"];

function getWeekBounds(): { weekStart: Date; weekEnd: Date } {
  const weekStart = getWeekStart();
  const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000);
  return { weekStart, weekEnd };
}

router.get("/weekly", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const metricParam = qs(req.query.metric) ?? "volume";
  const metric: Metric = VALID_METRICS.includes(metricParam as Metric)
    ? (metricParam as Metric)
    : "volume";

  const { weekStart, weekEnd } = getWeekBounds();
  const board = await service.getWeeklyBoard(userId, metric, weekStart, weekEnd);
  res.json(board);
});

router.get("/exercise/:name", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const name = req.params.name as string;
  const entries = await service.getExerciseBoard(userId, decodeURIComponent(name));
  res.json({ exercise: decodeURIComponent(name), entries });
});

router.get("/standings", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const { weekStart, weekEnd } = getWeekBounds();
  const standings = await service.getMyStandings(userId, weekStart, weekEnd);
  res.json(standings);
});

export default router;
