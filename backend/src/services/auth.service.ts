import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { pool, DbRow, DbResult } from '../config/db';
import { signToken, AuthPayload } from '../middlewares/auth';
import { ApiError } from '../utils/apiError';
import { generateUniqueUsername } from '../utils/username';
import { env } from '../config/env';

export interface RegisterInput {
  name: string;
  email: string;
  password: string;
  role: 'influencer' | 'brand';
  username?: string;
  brand_name?: string;
}

export const authService = {
  async register(input: RegisterInput) {
    const { name, email, password, role, username, brand_name } = input;

    const [existing] = await pool.query<DbRow[]>(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [email]
    );
    if (existing.length) throw new ApiError(409, 'Email already registered');

    const hash = await bcrypt.hash(password, 10);
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [ins] = await conn.query<DbResult>(
        'INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, ?)',
        [name, email, hash, role]
      );
      const userId = ins.insertId;

      if (role === 'influencer') {
        const u = await generateUniqueUsername(username ?? email.split('@')[0]);
        await conn.query(
          `INSERT INTO influencer_profiles (user_id, username) VALUES (?, ?)`,
          [userId, u]
        );
      } else {
        const b = brand_name ?? `${name}'s Brand`;
        await conn.query(
          `INSERT INTO brand_profiles (user_id, brand_name) VALUES (?, ?)`,
          [userId, b]
        );
      }

      await conn.commit();

      const payload: AuthPayload = { id: userId, role, email, name };
      const token = signToken(payload);
      return { token, user: payload };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  },

  async login(email: string, password: string) {
    const [rows] = await pool.query<DbRow[]>(
      'SELECT id, name, email, password_hash, role FROM users WHERE email = ? LIMIT 1',
      [email]
    );
    if (!rows.length) throw new ApiError(401, 'Invalid email or password');
    const user = rows[0] as { id: number; name: string; email: string; password_hash: string; role: 'influencer'|'brand' };
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) throw new ApiError(401, 'Invalid email or password');
    const payload: AuthPayload = { id: user.id, role: user.role, email: user.email, name: user.name };
    const token = signToken(payload);
    return { token, user: payload };
  },

  async forgotPassword(email: string) {
    const [rows] = await pool.query<DbRow[]>(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [email]
    );
    let devToken: string | undefined;
    if (rows.length) {
      const userId = (rows[0] as { id: number }).id;
      const token = crypto.randomBytes(32).toString('hex');
      await pool.query(
        `INSERT INTO password_resets (user_id, token, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 MINUTE))`,
        [userId, token]
      );
      console.log(`[dev] password reset requested for ${email} — token: ${token} (expires in 30 min)`);
      if (env.nodeEnv !== 'production') devToken = token;
    }
    return { delivered: true, ...(devToken ? { dev_token: devToken } : {}) };
  },

  async resetPassword(token: string, newPassword: string) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT user_id FROM password_resets WHERE token = ? AND expires_at > NOW() LIMIT 1`,
      [token]
    );
    if (!rows.length) throw new ApiError(400, 'This reset link is invalid or has expired');
    const userId = (rows[0] as { user_id: number }).user_id;
    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, userId]);
    await pool.query('DELETE FROM password_resets WHERE user_id = ?', [userId]);
    return { ok: true };
  },

  async changePassword(userId: number, currentPassword: string, newPassword: string) {
    const [rows] = await pool.query<DbRow[]>(
      'SELECT password_hash FROM users WHERE id = ?',
      [userId]
    );
    if (!rows.length) throw new ApiError(404, 'User not found');
    const { password_hash } = rows[0] as { password_hash: string };
    const ok = await bcrypt.compare(currentPassword, password_hash);
    if (!ok) throw new ApiError(400, 'Current password is incorrect');
    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, userId]);
    return { ok: true };
  },
};