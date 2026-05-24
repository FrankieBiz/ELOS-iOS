import "dotenv/config";
import { assertRequiredEnv } from "./lib/env";
assertRequiredEnv();

import express from "express";
import helmet from "helmet";
import cors from "cors";
import rateLimit from "express-rate-limit";
import { pinoHttp } from "pino-http";
import { logger } from "./lib/logger";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler";
import authRouter from "./routes/auth";
import profileRouter from "./routes/profile";
import sessionsRouter from "./routes/sessions";
import exercisesRouter from "./routes/exercises";
import templatesRouter from "./routes/templates";
import analyticsRouter from "./routes/analytics";
import readinessRouter from "./routes/readiness";
import libraryRouter from "./routes/library";
import machinesRouter from "./routes/machines";
import socialRouter from "./routes/social";
import leaderboardRouter from "./routes/leaderboard";
import splitsRouter from "./routes/splits";

const app = express();
const port = process.env.PORT || 3000;

const allowedOrigins = (process.env.CORS_ORIGINS ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

app.use(pinoHttp({ logger }));
app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (process.env.NODE_ENV !== "production") return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      callback(new Error("CORS: origin not allowed"));
    },
    credentials: true,
  })
);
app.use(express.json({ limit: "32kb" }));

const globalLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: "draft-7",
  legacyHeaders: false,
});
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: "draft-7",
  legacyHeaders: false,
});

app.use(globalLimiter);
app.use("/auth", authLimiter);

app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "elos-api" });
});

app.use("/auth", authRouter);
app.use("/profile", profileRouter);
app.use("/sessions", sessionsRouter);
app.use("/exercises", exercisesRouter);
app.use("/templates", templatesRouter);
app.use("/analytics", analyticsRouter);
app.use("/readiness", readinessRouter);
app.use("/library", libraryRouter);
app.use("/machines", machinesRouter);
app.use("/social", socialRouter);
app.use("/leaderboard", leaderboardRouter);
app.use("/splits", splitsRouter);

app.use(notFoundHandler);
app.use(errorHandler);

process.on("unhandledRejection", (reason) => {
  logger.error({ reason: reason instanceof Error ? reason.message : String(reason), stack: reason instanceof Error ? reason.stack : undefined }, "unhandledRejection");
});

process.on("uncaughtException", (err) => {
  logger.fatal({ err }, "uncaughtException");
  process.exit(1);
});

app.listen(port, () => {
  logger.info({ port }, "elos-api listening");
});
