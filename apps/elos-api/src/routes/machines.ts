import { Router, Request, Response } from "express";
import { requireAuth } from "../middleware/auth";
import { MachineService } from "../services/machineService";
import { pool } from "../db";

const router = Router();
const service = new MachineService(pool);

router.use(requireAuth);

const qs = (v: unknown): string | undefined => (typeof v === "string" ? v : undefined);

router.get("/", async (req: Request, res: Response) => {
  const machines = await service.getMachines({
    category: qs(req.query.category),
    equipment: qs(req.query.equipment),
    brand: qs(req.query.brand),
  });
  res.json({ machines });
});

router.get("/categories", async (_req: Request, res: Response) => {
  const categories = await service.getMachinesByCategory();
  res.json(categories);
});

router.get("/brands", async (_req: Request, res: Response) => {
  const brands = await service.getBrands();
  res.json({ brands });
});

router.get("/by-brand", async (_req: Request, res: Response) => {
  const groups = await service.getMachinesByBrand();
  res.json({ groups });
});

router.get("/search", async (req: Request, res: Response) => {
  const q = qs(req.query.q) ?? "";
  if (!q.trim()) { res.json({ machines: [] }); return; }
  const machines = await service.searchMachines(q);
  res.json({ machines });
});

router.get("/:slug", async (req: Request, res: Response) => {
  const machine = await service.getMachineDetail(req.params.slug as string);
  if (!machine) { res.status(404).json({ error: "Machine not found" }); return; }
  res.json(machine);
});

export default router;
