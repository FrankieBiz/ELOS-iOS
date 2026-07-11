import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { CommunitySplitService } from "../services/communitySplitService";
import { pool } from "../db";
import { publishSplitSchema } from "../schemas";

const router = Router();
const service = new CommunitySplitService(pool);

router.post("/", requireAuth, validateBody(publishSplitSchema), async (req: Request, res: Response) => {
  const { split_id, description = "" } = req.body as { split_id: string; description?: string };
  const published = await service.publish(req.user!.id, split_id, description);
  if (!published) { res.status(404).json({ error: "Split not found" }); return; }
  res.status(201).json(published);
});

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const cursor = typeof req.query.cursor === "string" ? req.query.cursor : undefined;
  const page = await service.list(req.user!.id, cursor);
  res.json(page);
});

router.get("/mine", requireAuth, async (req: Request, res: Response) => {
  const splits = await service.listMine(req.user!.id);
  res.json({ splits });
});

router.post("/:id/import", requireAuth, async (req: Request, res: Response) => {
  const split = await service.importSplit(req.user!.id, req.params.id as string);
  if (!split) { res.status(404).json({ error: "Community split not found" }); return; }
  res.status(201).json(split);
});

router.delete("/:id", requireAuth, async (req: Request, res: Response) => {
  const deleted = await service.unpublish(req.user!.id, req.params.id as string);
  if (!deleted) { res.status(404).json({ error: "Community split not found" }); return; }
  res.status(204).send();
});

export default router;
