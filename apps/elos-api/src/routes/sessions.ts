import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { SessionService } from "../services/sessionService";
import { pool } from "../db";
import { createSessionSchema, updateSessionSchema, createSetSchema } from "../schemas";

const router = Router();
const service = new SessionService(pool);

router.post("/", requireAuth, validateBody(createSessionSchema), async (req: Request, res: Response) => {
  const session = await service.createSession(req.user!.id, req.body);
  res.status(201).json(session);
});

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const limit = Math.min(Number(req.query.limit ?? 30), 100);
  const sessions = await service.getSessionsForUser(req.user!.id, limit);
  res.json({ sessions });
});

router.get("/:id", requireAuth, async (req: Request, res: Response) => {
  const id = req.params.id as string;
  const session = await service.getSession(id, req.user!.id);
  if (!session) { res.status(404).json({ error: "Session not found" }); return; }
  const sets = await service.getSessionSets(id, req.user!.id);
  res.json({ ...session, sets });
});

router.patch("/:id", requireAuth, validateBody(updateSessionSchema), async (req: Request, res: Response) => {
  const session = await service.updateSession(req.params.id as string, req.user!.id, req.body);
  if (!session) { res.status(404).json({ error: "Session not found" }); return; }
  res.json(session);
});

router.delete("/:id", requireAuth, async (req: Request, res: Response) => {
  const deleted = await service.deleteSession(req.params.id as string, req.user!.id);
  if (!deleted) { res.status(404).json({ error: "Session not found" }); return; }
  res.status(204).send();
});

router.post("/:id/sets", requireAuth, validateBody(createSetSchema), async (req: Request, res: Response) => {
  const id = req.params.id as string;
  const session = await service.getSession(id, req.user!.id);
  if (!session) { res.status(404).json({ error: "Session not found" }); return; }
  const set = await service.addSet(id, req.user!.id, req.body);
  res.status(201).json(set);
});

router.get("/:id/sets", requireAuth, async (req: Request, res: Response) => {
  const id = req.params.id as string;
  const session = await service.getSession(id, req.user!.id);
  if (!session) { res.status(404).json({ error: "Session not found" }); return; }
  const sets = await service.getSessionSets(id, req.user!.id);
  res.json({ sets });
});

export default router;
