import { Request, Response, NextFunction } from "express";
import type { ErrorResponse } from "elos-shared";
import { HttpError } from "../lib/httpError";
import { logger } from "../lib/logger";

export function notFoundHandler(_req: Request, res: Response): void {
  const body: ErrorResponse = { error: "Not found", code: "NOT_FOUND" };
  res.status(404).json(body);
}

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (res.headersSent) {
    return;
  }

  if (err instanceof HttpError) {
    const body: ErrorResponse = { error: err.message };
    if (err.code) body.code = err.code;
    res.status(err.status).json(body);
    return;
  }

  logger.error(
    {
      method: req.method,
      path: req.path,
      err: err instanceof Error ? { message: err.message, stack: err.stack } : err,
    },
    "request error"
  );

  const isProd = process.env.NODE_ENV === "production";
  const message = err instanceof Error ? err.message : "Internal server error";
  const body: ErrorResponse = {
    error: isProd ? "Internal server error" : message,
    code: "INTERNAL",
  };
  res.status(500).json(body);
}
