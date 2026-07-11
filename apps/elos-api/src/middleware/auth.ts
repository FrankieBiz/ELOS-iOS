import { Request, Response, NextFunction } from "express";
import { supabaseAdmin } from "../supabase";
import { logger } from "../lib/logger";

type CachedAuth = { user: { id: string; email: string }; expiresAt: number };

// Short-lived token→user cache: verifying with Supabase is a network round-trip
// (50–200ms) on EVERY authenticated request, and a Supabase blip would take the
// whole API down with it. 60s is far shorter than any access-token lifetime, so
// a revoked token stays usable for at most one minute.
const TOKEN_CACHE_TTL_MS = 60_000;
const TOKEN_CACHE_MAX = 5_000;
const tokenCache = new Map<string, CachedAuth>();

function cacheGet(token: string): CachedAuth["user"] | null {
  const hit = tokenCache.get(token);
  if (!hit) return null;
  if (hit.expiresAt < Date.now()) {
    tokenCache.delete(token);
    return null;
  }
  return hit.user;
}

function cacheSet(token: string, user: CachedAuth["user"]): void {
  if (tokenCache.size >= TOKEN_CACHE_MAX) {
    // Map iterates in insertion order — evict the oldest entry.
    const oldest = tokenCache.keys().next().value;
    if (oldest !== undefined) tokenCache.delete(oldest);
  }
  tokenCache.set(token, { user, expiresAt: Date.now() + TOKEN_CACHE_TTL_MS });
}

/** Test hook: clear the verification cache between test cases. */
export function _clearTokenCache(): void {
  tokenCache.clear();
}

export async function requireAuth(req: Request, res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  const token = authHeader.slice(7);

  const cached = cacheGet(token);
  if (cached) {
    req.user = cached;
    next();
    return;
  }

  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !user) {
    logger.warn(
      { path: req.path, reason: error?.message ?? "no user for token" },
      "auth token verification failed"
    );
    res.status(401).json({ error: "Invalid or expired token" });
    return;
  }
  const authed = { id: user.id, email: user.email ?? "" };
  cacheSet(token, authed);
  req.user = authed;
  next();
}
