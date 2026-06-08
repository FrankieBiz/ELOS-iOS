import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { LibraryService } from "../services/libraryService";
import { pool } from "../db";
import { saveWorkoutSchema } from "../schemas";
import { qs } from "../lib/query";

const router = Router();
const service = new LibraryService(pool);

router.use(requireAuth);

router.get("/creators", async (req: Request, res: Response) => {
  const creators = await service.getCreators({
    category: qs(req.query.category),
    difficulty: qs(req.query.difficulty),
    goal: qs(req.query.goal),
  });
  res.json({ creators });
});

router.get("/creators/:slug", async (req: Request, res: Response) => {
  const creator = await service.getCreator(req.params.slug as string);
  if (!creator) { res.status(404).json({ error: "Creator not found" }); return; }
  res.json(creator);
});

router.get("/workouts", async (req: Request, res: Response) => {
  const rawDays = req.query.days ? Number(req.query.days) : undefined;
  const days = rawDays !== undefined && Number.isFinite(rawDays) ? rawDays : undefined;
  const workouts = await service.getWorkouts({
    goal: qs(req.query.goal),
    split: qs(req.query.split),
    days,
  });
  res.json({ workouts });
});

router.get("/workouts/:id", async (req: Request, res: Response) => {
  const workout = await service.getWorkoutDetail(req.params.id as string);
  if (!workout) { res.status(404).json({ error: "Workout not found" }); return; }
  res.json(workout);
});

router.get("/search", async (req: Request, res: Response) => {
  const q = qs(req.query.q) ?? "";
  const type = qs(req.query.type);
  if (!q.trim()) { res.json({ creators: [], workouts: [], machines: [] }); return; }
  const results = await service.searchLibrary(q, type);
  res.json(results);
});

router.post("/saved", requireAuth, validateBody(saveWorkoutSchema), async (req: Request, res: Response) => {
  const { workoutId } = req.body as { workoutId: string };
  await service.saveWorkout(req.user!.id, workoutId);
  res.status(201).json({ ok: true });
});

router.delete("/saved/:workoutId", requireAuth, async (req: Request, res: Response) => {
  await service.unsaveWorkout(req.user!.id, req.params.workoutId as string);
  res.json({ ok: true });
});

router.get("/saved", requireAuth, async (req: Request, res: Response) => {
  const workouts = await service.getSavedWorkouts(req.user!.id);
  res.json({ workouts });
});

export default router;
