import jwt from 'jsonwebtoken';

const ACCESS_TOKEN_SECRET = process.env.JWT_ACCESS_SECRET || 'access-secret-dev';
const REFRESH_TOKEN_SECRET = process.env.JWT_REFRESH_SECRET || 'refresh-secret-dev';

export const generateAccessToken = (userId: string) => {
  return jwt.sign({ userId }, ACCESS_TOKEN_SECRET, { expiresIn: '15m' });
};

export const generateRefreshToken = (userId: string, deviceId: string) => {
  return jwt.sign({ userId, deviceId }, REFRESH_TOKEN_SECRET, { expiresIn: '7d' });
};

export const verifyAccessToken = (token: string) => {
  return jwt.verify(token, ACCESS_TOKEN_SECRET) as { userId: string };
};

export const verifyRefreshToken = (token: string) => {
  return jwt.verify(token, REFRESH_TOKEN_SECRET) as { userId: string, deviceId: string };
};
