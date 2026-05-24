import { Router, Request, Response } from "express";
import rateLimit from "express-rate-limit";
import { requireAuth } from "../middleware/auth";
import { AiService } from "../services/aiService";
import { pool } from "../db";

const router = Router();
const service = new AiService(pool);

const briefLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  limit: 5,
  keyGenerator: (req) => (req as any).user?.id ?? req.ip,
  standardHeaders: "draft-7",
  legacyHeaders: false,
});

router.post("/brief", requireAuth, briefLimiter, async (req: Request, res: Response) => {
  const clientCtx = req.body?.client_context ?? {};
  const force = req.body?.force === true;
  try {
    const brief = await service.getBrief(req.user!.id, clientCtx, force);
    res.json(brief);
  } catch {
    res.status(503).json({ error: "brief_unavailable" });
  }
});

export default router;
