import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { TemplateService } from "../services/templateService";
import { pool } from "../db";
import { createTemplateSchema, updateTemplateNameSchema } from "../schemas";

const router = Router();
const service = new TemplateService(pool);

router.get("/", requireAuth, async (req: Request, res: Response) => {
  const templates = await service.getTemplatesForUser(req.user!.id);
  res.json({ templates });
});

router.post("/", requireAuth, validateBody(createTemplateSchema), async (req: Request, res: Response) => {
  const template = await service.createTemplate(req.user!.id, req.body);
  res.status(201).json(template);
});

router.patch("/:id", requireAuth, validateBody(updateTemplateNameSchema), async (req: Request, res: Response) => {
  const { name } = req.body as { name: string };
  const template = await service.updateTemplateName(req.params.id as string, req.user!.id, name);
  if (!template) { res.status(404).json({ error: "Template not found" }); return; }
  res.json(template);
});

router.delete("/:id", requireAuth, async (req: Request, res: Response) => {
  const deleted = await service.deleteTemplate(req.params.id as string, req.user!.id);
  if (!deleted) { res.status(404).json({ error: "Template not found" }); return; }
  res.status(204).send();
});

export default router;
