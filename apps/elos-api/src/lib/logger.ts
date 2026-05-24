import pino from "pino";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? (process.env.NODE_ENV === "production" ? "info" : "debug"),
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      'req.body.password',
      'req.body.token',
      'req.body.refresh_token',
      'req.body.access_token',
    ],
    censor: "[REDACTED]",
  },
});
