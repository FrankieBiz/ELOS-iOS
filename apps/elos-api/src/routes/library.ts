import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { LibraryService } from "../services/libraryService";
import { pool } from "../db";

const router = Router();
const service = new LibraryService(pool);

router.use(requireAuth);

const qs = (v: unknown): string | undefined => (typeof v === "string" ? v : undefined);

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
  const days = req.query.days ? Number(req.query.days) : undefined;
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

router.post("/saved", requireAuth, async (req: Request, res: Response) => {
  const { workoutId } = req.body as { workoutId: string };
  if (!workoutId) { res.status(400).json({ error: "workoutId required" }); return; }
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
