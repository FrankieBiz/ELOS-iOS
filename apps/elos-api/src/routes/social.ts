import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { FriendService } from "../services/friendService";
import { pool } from "../db";
import { friendRequestSchema, reportUserSchema, blockUserSchema } from "../schemas";
import { qs } from "../lib/query";

const router = Router();
const service = new FriendService(pool);

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

router.get("/friends/sent", requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const requests = await service.getSentRequests(userId);
  res.json({ requests });
});

router.post("/friends/request", requireAuth, validateBody(friendRequestSchema), async (req: Request, res: Response) => {
  const userId = req.user!.id;
  const { addresseeId } = req.body as { addresseeId: string };
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

router.get("/profile/:userId", requireAuth, async (req: Request, res: Response) => {
  const profile = await service.getPublicProfile(req.params.userId as string);
  if (!profile) { res.status(404).json({ error: "User not found" }); return; }
  res.json(profile);
});

router.get("/friends/:userId/stats", requireAuth, async (req: Request, res: Response) => {
  const viewerId = req.user!.id;
  const stats = await service.getFriendStats(viewerId, req.params.userId as string);
  if (!stats) { res.status(403).json({ error: "Not friends or user not found" }); return; }
  res.json(stats);
});

router.post("/report", requireAuth, validateBody(reportUserSchema), async (req: Request, res: Response) => {
  const reporterId = req.user!.id;
  const { reportedId, category, note } = req.body as {
    reportedId: string;
    category: string;
    note?: string;
  };
  await service.reportUser(reporterId, reportedId, category, note);
  res.status(201).json({ ok: true });
});

router.post("/block", requireAuth, validateBody(blockUserSchema), async (req: Request, res: Response) => {
  const { blockedId } = req.body as { blockedId: string };
  await service.blockUser(req.user!.id, blockedId);
  res.status(201).json({ ok: true });
});

router.delete("/block/:userId", requireAuth, async (req: Request, res: Response) => {
  await service.unblockUser(req.user!.id, req.params.userId as string);
  res.json({ ok: true });
});

export default router;
