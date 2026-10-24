import jwt from 'jsonwebtoken';

// No fallbacks: a missing secret must stop the server, never silently use a public default.
function requireSecret(name: 'JWT_ACCESS_SECRET' | 'JWT_REFRESH_SECRET'): string {
  const value = process.env[name];
  if (!value || value.length < 32) {
    throw new Error(`${name} must be set to a random string of at least 32 characters`);
  }
  return value;
}

/** Call once at startup so misconfiguration fails fast instead of on the first login. */
export const assertJwtSecrets = () => {
  requireSecret('JWT_ACCESS_SECRET');
  requireSecret('JWT_REFRESH_SECRET');
};

export const generateAccessToken = (userId: string) => {
  return jwt.sign({ userId }, requireSecret('JWT_ACCESS_SECRET'), { expiresIn: '15m' });
};

export const generateRefreshToken = (userId: string, deviceId: string) => {
  return jwt.sign({ userId, deviceId }, requireSecret('JWT_REFRESH_SECRET'), { expiresIn: '7d' });
};

export const verifyAccessToken = (token: string) => {
  return jwt.verify(token, requireSecret('JWT_ACCESS_SECRET'), { algorithms: ['HS256'] }) as { userId: string };
};

export const verifyRefreshToken = (token: string) => {
  return jwt.verify(token, requireSecret('JWT_REFRESH_SECRET'), { algorithms: ['HS256'] }) as { userId: string, deviceId: string };
};
