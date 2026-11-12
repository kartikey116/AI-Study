import pino from 'pino';

/**
 * Structured JSON logs (one object per line) so a log platform can search by
 * requestId, userId, documentId, etc. Never log message contents, document text,
 * tokens or passwords — only ids, counts and error messages.
 */
export const logger = pino({
  level: process.env.LOG_LEVEL ?? (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
  base: { service: process.env.SERVICE_NAME ?? 'studyai-api' },
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.refreshToken', '*.accessToken'],
    remove: true,
  },
});
