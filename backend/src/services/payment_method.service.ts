import { pool, DbRow, DbResult } from '../config/db';
import { ApiError } from '../utils/apiError';

export interface AddPaymentMethodInput {
  type: 'bank_transfer' | 'card' | 'e_wallet';
  label: string;
  provider?: string;
  last4?: string;
  is_default?: boolean;
}

export const paymentMethodService = {
  async list(brandUserId: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT id, type, label, provider, last4, is_default, created_at
         FROM brand_payment_methods
        WHERE brand_user_id = ?
        ORDER BY is_default DESC, created_at DESC`,
      [brandUserId]
    );
    return rows;
  },

  async add(brandUserId: number, input: AddPaymentMethodInput) {
    if (!input.label?.trim()) throw new ApiError(400, 'A label/name is required');
    if (!['bank_transfer', 'card', 'e_wallet'].includes(input.type)) {
      throw new ApiError(400, 'Invalid payment method type');
    }
    if (input.last4 && !/^\d{4}$/.test(input.last4)) {
      throw new ApiError(400, 'last4 must be exactly 4 digits');
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const [existing] = await conn.query<DbRow[]>(
        `SELECT COUNT(*) AS n FROM brand_payment_methods WHERE brand_user_id = ?`,
        [brandUserId]
      );
      const isFirst = (existing[0] as { n: number }).n === 0;
      const makeDefault = input.is_default === true || isFirst;

      if (makeDefault) {
        await conn.query(
          `UPDATE brand_payment_methods SET is_default = 0 WHERE brand_user_id = ?`,
          [brandUserId]
        );
      }

      const [r] = await conn.query<DbResult>(
        `INSERT INTO brand_payment_methods (brand_user_id, type, label, provider, last4, is_default)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [brandUserId, input.type, input.label.trim(), input.provider ?? null, input.last4 ?? null, makeDefault ? 1 : 0]
      );
      await conn.commit();
      return { id: r.insertId, ...input, is_default: makeDefault };
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  },

  async remove(brandUserId: number, id: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT is_default FROM brand_payment_methods WHERE id = ? AND brand_user_id = ?`,
      [id, brandUserId]
    );
    if (!rows.length) throw new ApiError(404, 'Payment method not found');
    const wasDefault = (rows[0] as { is_default: number }).is_default === 1;

    await pool.query(
      `DELETE FROM brand_payment_methods WHERE id = ? AND brand_user_id = ?`,
      [id, brandUserId]
    );
    if (wasDefault) {
      await pool.query(
        `UPDATE brand_payment_methods SET is_default = 1
          WHERE brand_user_id = ? ORDER BY created_at DESC LIMIT 1`,
        [brandUserId]
      );
    }
    return { deleted: true };
  },

  async setDefault(brandUserId: number, id: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT id FROM brand_payment_methods WHERE id = ? AND brand_user_id = ?`,
      [id, brandUserId]
    );
    if (!rows.length) throw new ApiError(404, 'Payment method not found');
    await pool.query(`UPDATE brand_payment_methods SET is_default = 0 WHERE brand_user_id = ?`, [brandUserId]);
    await pool.query(`UPDATE brand_payment_methods SET is_default = 1 WHERE id = ?`, [id]);
    return { ok: true };
  },
};