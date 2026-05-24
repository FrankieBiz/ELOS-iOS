import { Router, Request, Response } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth";
import { validateBody, validateQuery } from "../middleware/validate";
import { ExerciseService, ExerciseSearchFilters } from "../services/exerciseService";
import { pool } from "../db";
import { createExerciseSchema, searchExercisesQuerySchema } from "../schemas";

const router = Router();
const service = new ExerciseService(pool);

type SearchQuery = z.infer<typeof searchExercisesQuerySchema>;
type RequestWithQuery<T> = Request & { validatedQuery: T };

router.get(
  "/",
  requireAuth,
  validateQuery(searchExercisesQuerySchema),
  async (req: Request, res: Response) => {
    const q = (req as RequestWithQuery<SearchQuery>).validatedQuery;
    const filters: ExerciseSearchFilters = {
      q: q.q,
      primary_muscle: q.primary_muscle,
      equipment: q.equipment,
      movement_pattern: q.movement_pattern,
      brand_slug: q.brand_slug,
      is_custom: q.is_custom,
      limit: q.limit,
      offset: q.offset,
    };
    const exercises = await service.searchExercises(req.user!.id, filters);
    res.json({ exercises });
  }
);

router.get("/recent", requireAuth, async (req: Request, res: Response) => {
  const limit = Math.min(Math.max(Number(req.query.limit ?? 10), 1), 50);
  const exercises = await service.getRecentExercises(req.user!.id, limit);
  res.json({ exercises });
});

router.get("/favorites", requireAuth, async (req: Request, res: Response) => {
  const exercises = await service.getFavorites(req.user!.id);
  res.json({ exercises });
});

router.post(
  "/:id/favorite",
  requireAuth,
  async (req: Request, res: Response) => {
    await service.favoriteExercise(req.user!.id, req.params.id as string);
    res.status(201).json({ ok: true });
  }
);

router.delete(
  "/:id/favorite",
  requireAuth,
  async (req: Request, res: Response) => {
    await service.unfavoriteExercise(req.user!.id, req.params.id as string);
    res.status(204).send();
  }
);

router.post("/", requireAuth, validateBody(createExerciseSchema), async (req: Request, res: Response) => {
  const exercise = await service.createCustomExercise(req.user!.id, req.body);
  res.status(201).json(exercise);
});

export default router;
