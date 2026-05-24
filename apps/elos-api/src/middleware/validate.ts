import { Request, Response, NextFunction } from "express";
import { ZodSchema, ZodError } from "zod";
import { badRequest } from "../lib/httpError";

function handleZodIssue(err: unknown, location: string, next: NextFunction): void {
  if (err instanceof ZodError) {
    const issue = err.issues[0];
    const path = issue?.path.join(".") || location;
    next(badRequest(`${path}: ${issue?.message ?? "invalid input"}`, "VALIDATION"));
    return;
  }
  next(err);
}

export function validateBody<T>(schema: ZodSchema<T>) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      handleZodIssue(err, "body", next);
    }
  };
}

export function validateQuery<T>(schema: ZodSchema<T>) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req.query);
      (req as Request & { validatedQuery: T }).validatedQuery = parsed;
      next();
    } catch (err) {
      handleZodIssue(err, "query", next);
    }
  };
}
