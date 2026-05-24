import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { SplitService } from "../services/splitService";
import { pool } from "../db";
import { createSplitSchema } from "../schemas";

const router = Router();
const service = new SplitService(pool);

router.post("/", requireAuth, validateBody(createSplitSchema), async (req: Request, res: Response) => {
  const result = await service.createSplit(req.user!.id, req.body);
  if (result.conflict) {
    res.status(409).json({ conflict: true, existing_id: result.existingId });
    return;
  }
  res.status(201).json(result.split);
});

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const splits = await service.getUserSplits(req.user!.id);
  res.json(splits);
});

router.delete("/:id", requireAuth, async (req: Request, res: Response) => {
  const deleted = await service.deleteSplit(req.user!.id, req.params.id as string);
  if (!deleted) { res.status(404).json({ error: "Split not found" }); return; }
  res.status(204).send();
});

router.patch("/:id/activate", requireAuth, async (req: Request, res: Response) => {
  const split = await service.activateSplit(req.user!.id, req.params.id as string);
  if (!split) { res.status(404).json({ error: "Split not found" }); return; }
  res.json(split);
});

export default router;
