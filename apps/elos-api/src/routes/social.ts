import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { FriendService } from "../services/friendService";
import { pool } from "../db";

const router = Router();
const service = new FriendService(pool);

const qs = (v: unknown): string | undefined => (typeof v === "string" ? v : undefined);

router.get("/friends", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const friends = await service.getFriends(userId);
  res.json({ friends });
});

router.get("/friends/requests", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const requests = await service.getPendingRequests(userId);
  res.json({ requests });
});

router.post("/friends/request", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const { addresseeId } = req.body as { addresseeId?: string };
  if (!addresseeId) { res.status(400).json({ error: "addresseeId required" }); return; }
  await service.sendRequest(userId, addresseeId);
  res.status(201).json({ ok: true });
});

router.patch("/friends/:id/accept", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  await service.acceptRequest(userId, req.params.id as string);
  res.json({ ok: true });
});

router.patch("/friends/:id/decline", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  await service.declineRequest(userId, req.params.id as string);
  res.json({ ok: true });
});

router.delete("/friends/:id", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  await service.removeFriend(userId, req.params.id as string);
  res.json({ ok: true });
});

router.get("/search", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const q = qs(req.query.q);
  if (!q || q.trim().length < 1) { res.json({ users: [] }); return; }
  const users = await service.searchUsers(q.trim(), userId);
  res.json({ users });
});

router.get("/friends/:userId/stats", requireAuth, async (req: Request, res: Response) => {
  const viewerId = req.user!.id;
  const stats = await service.getFriendStats(viewerId, req.params.userId as string);
  if (!stats) { res.status(403).json({ error: "Not friends or user not found" }); return; }
  res.json(stats);
});

export default router;
