import { pool, DbRow, DbResult } from '../config/db';
import { ApiError } from '../utils/apiError';
import { notificationService } from './notification.service';
const MIN_WITHDRAWAL = 50_000;

export const withdrawalService = {
  async getBalance(influencerUserId: number) {
    const [[earned]] = await pool.query<DbRow[]>(
      `SELECT COALESCE(SUM(amount), 0) AS s FROM earnings WHERE influencer_user_id = ?`,
      [influencerUserId]
    );
    const [[withdrawn]] = await pool.query<DbRow[]>(
      `SELECT COALESCE(SUM(amount), 0) AS s FROM withdrawals
        WHERE influencer_user_id = ? AND status IN ('pending', 'processing', 'completed')`,
      [influencerUserId]
    );
    const totalEarned = Number((earned as { s: number }).s) || 0;
    const totalWithdrawn = Number((withdrawn as { s: number }).s) || 0;
    return {
      total_earned: totalEarned,
      total_withdrawn: totalWithdrawn,
      available: Math.max(0, totalEarned - totalWithdrawn),
      min_withdrawal: MIN_WITHDRAWAL,
    };
  },

  async requestWithdrawal(
    influencerUserId: number,
    input: { amount: number; bank_name: string; account_number: string; account_name: string }
  ) {
    const amount = Number(input.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new ApiError(400, 'Invalid amount');
    }
    if (amount < MIN_WITHDRAWAL) {
      throw new ApiError(400, `Minimum withdrawal is Rp ${MIN_WITHDRAWAL.toLocaleString('id-ID')}`);
    }
    if (!input.bank_name?.trim() || !input.account_number?.trim() || !input.account_name?.trim()) {
      throw new ApiError(400, 'Bank name, account number, and account holder name are required');
    }

    const balance = await this.getBalance(influencerUserId);
    if (amount > balance.available) {
      throw new ApiError(400, `You can only withdraw up to Rp ${balance.available.toLocaleString('id-ID')}`);
    }

    const [r] = await pool.query<DbResult>(
      `INSERT INTO withdrawals (influencer_user_id, amount, bank_name, account_number, account_name, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [influencerUserId, amount, input.bank_name.trim(), input.account_number.trim(), input.account_name.trim()]
    );
    await pool.query(
      `UPDATE influencer_profiles SET payout_bank = ?, payout_account = ? WHERE user_id = ?`,
      [input.bank_name.trim(), input.account_number.trim(), influencerUserId]
    );

    try {
      await notificationService.push(influencerUserId, {
        type: 'withdrawal',
        title: 'Withdrawal requested',
        body: `Your request to withdraw Rp ${amount.toLocaleString('id-ID')} has been received and is being reviewed.`,
        data: { withdrawal_id: r.insertId },
      });
    } catch {  }

    return { id: r.insertId, amount, status: 'pending' };
  },

  async listMine(influencerUserId: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT id, amount, bank_name, account_number, account_name, status, notes, requested_at, processed_at
         FROM withdrawals
        WHERE influencer_user_id = ?
        ORDER BY requested_at DESC`,
      [influencerUserId]
    );
    return rows;
  },
};