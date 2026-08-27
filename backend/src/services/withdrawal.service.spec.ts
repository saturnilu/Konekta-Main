import { withdrawalService } from './withdrawal.service';
import { pool } from '../config/db';
import { ApiError } from '../utils/apiError';

jest.mock('../config/db', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('./notification.service', () => ({
  notificationService: { push: jest.fn().mockResolvedValue(undefined) },
}));

const validInput = {
  bank_name: 'BCA',
  account_number: '1234567890',
  account_name: 'Ava Influencer',
};

function mockBalance(totalEarned: number, totalWithdrawn: number) {
  (pool.query as jest.Mock)
    .mockResolvedValueOnce([[{ s: totalEarned }]])
    .mockResolvedValueOnce([[{ s: totalWithdrawn }]]);
}

describe('withdrawalService.requestWithdrawal (financial boundary validation)', () => {
  it('rejects an amount of zero', async () => {
    await expect(
      withdrawalService.requestWithdrawal(1, { ...validInput, amount: 0 })
    ).rejects.toMatchObject({ status: 400 });
  });

  it('rejects a negative amount', async () => {
    await expect(
      withdrawalService.requestWithdrawal(1, { ...validInput, amount: -50_000 })
    ).rejects.toMatchObject({ status: 400 });
  });

  it('rejects an amount below the minimum withdrawal (Rp 50,000)', async () => {
    await expect(
      withdrawalService.requestWithdrawal(1, { ...validInput, amount: 49_999 })
    ).rejects.toMatchObject({ status: 400 });
  });

  it('rejects an amount exceeding the available balance', async () => {
    mockBalance(100_000, 0); 

    await expect(
      withdrawalService.requestWithdrawal(1, { ...validInput, amount: 150_000 })
    ).rejects.toBeInstanceOf(ApiError);
  });

  it('rejects when bank details are missing or blank', async () => {
    await expect(
      withdrawalService.requestWithdrawal(1, { ...validInput, amount: 100_000, bank_name: '  ' })
    ).rejects.toMatchObject({ status: 400 });
  });

  it('accepts a valid amount exactly at the available balance and inserts the withdrawal', async () => {
    mockBalance(100_000, 0); 
    (pool.query as jest.Mock)
      .mockResolvedValueOnce([{ insertId: 42 }]) 
      .mockResolvedValueOnce([{}]); 

    const result = await withdrawalService.requestWithdrawal(1, { ...validInput, amount: 100_000 });

    expect(result).toEqual({ id: 42, amount: 100_000, status: 'pending' });
  });

  it('accepts a valid amount exactly at the minimum withdrawal boundary', async () => {
    mockBalance(1_000_000, 0);
    (pool.query as jest.Mock).mockResolvedValueOnce([{ insertId: 43 }]).mockResolvedValueOnce([{}]);

    const result = await withdrawalService.requestWithdrawal(1, { ...validInput, amount: 50_000 });

    expect(result.amount).toBe(50_000);
  });
});