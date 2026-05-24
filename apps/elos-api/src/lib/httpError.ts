export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly code?: string
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export function badRequest(message: string, code?: string): HttpError {
  return new HttpError(400, message, code);
}

export function unauthorized(message = "Unauthorized", code?: string): HttpError {
  return new HttpError(401, message, code);
}

export function forbidden(message = "Forbidden", code?: string): HttpError {
  return new HttpError(403, message, code);
}

export function notFound(message = "Not found", code?: string): HttpError {
  return new HttpError(404, message, code);
}

export function conflict(message: string, code?: string): HttpError {
  return new HttpError(409, message, code);
}
