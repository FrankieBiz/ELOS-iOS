import { Router, Request, Response } from "express";
import type { FeedPayload } from "elos-shared";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { FeedService } from "../services/feedService";
import { pool } from "../db";
import { createFeedPostSchema, reactSchema } from "../schemas";
import { badRequest, notFound } from "../lib/httpError";
import { qs } from "../lib/query";

const router = Router();
const service = new FeedService(pool);

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const page = await service.getFeed(req.user!.id, qs(req.query.cursor));
  res.json(page);
});

router.post("/", requireAuth, validateBody(createFeedPostSchema), async (req: Request, res: Response) => {
  const { kind, payload } = req.body as { kind: "workout" | "pr"; payload: FeedPayload };
  const post = await service.createPost(req.user!.id, kind, payload);
  res.status(201).json(post);
});

router.post("/split/:splitId", requireAuth, async (req: Request, res: Response) => {
  const post = await service.shareSplit(req.user!.id, req.params.splitId as string);
  if (!post) throw notFound("Split not found");
  res.status(201).json(post);
});

router.post("/:id/import", requireAuth, async (req: Request, res: Response) => {
  const kind = await service.getPostKind(req.params.id as string);
  if (!kind) throw notFound("Post not found");
  if (!(await service.canView(req.user!.id, req.params.id as string))) throw notFound("Post not found");
  if (kind !== "split") throw badRequest("Only split posts can be imported");
  const split = await service.importSplit(req.user!.id, req.params.id as string);
  if (!split) throw badRequest("Could not import split");
  res.status(201).json(split);
});

router.put("/:id/react", requireAuth, validateBody(reactSchema), async (req: Request, res: Response) => {
  const { emoji } = req.body as { emoji: string };
  if (!service.isValidEmoji(emoji)) throw badRequest("Unsupported reaction");
  if (!(await service.canView(req.user!.id, req.params.id as string))) throw notFound("Post not found");
  await service.react(req.user!.id, req.params.id as string, emoji);
  res.json({ ok: true });
});

router.delete("/:id/react", requireAuth, async (req: Request, res: Response) => {
  if (!(await service.canView(req.user!.id, req.params.id as string))) throw notFound("Post not found");
  await service.unreact(req.user!.id, req.params.id as string);
  res.json({ ok: true });
});

router.delete("/:id", requireAuth, async (req: Request, res: Response) => {
  const deleted = await service.deletePost(req.user!.id, req.params.id as string);
  if (!deleted) throw notFound("Post not found");
  res.status(204).send();
});

export default router;
