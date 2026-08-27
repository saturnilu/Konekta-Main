import { Request, Response, NextFunction } from 'express';
import { socialController } from './social.controller';
import { pool } from '../config/db';
import { ApiError } from '../utils/apiError';

jest.mock('../config/db', () => ({
  pool: { query: jest.fn() },
}));

function mockReqRes(overrides: Partial<Request> = {}) {
  const req = {
    user: { id: 1, role: 'influencer', email: 'a@test.com', name: 'A' },
    params: { id: '8' },
    ...overrides,
  } as unknown as Request;
  const res = {
    json: jest.fn(),
    status: jest.fn().mockReturnThis(),
  } as unknown as Response;
  const next = jest.fn() as NextFunction;
  return { req, res, next };
}

describe('socialController.remove (regression: BUG-003)', () => {
  it("calls next with a 404 ApiError when the DELETE affects 0 rows (not the caller's account)", async () => {
    (pool.query as jest.Mock).mockResolvedValue([{ affectedRows: 0 }]);
    const { req, res, next } = mockReqRes();

    await socialController.remove(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const err = (next as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(404);
    expect(res.json).not.toHaveBeenCalled();
  });

  it('responds 200 with deleted:true when the DELETE actually affects a row', async () => {
    (pool.query as jest.Mock).mockResolvedValue([{ affectedRows: 1 }]);
    const { req, res, next } = mockReqRes();

    await socialController.remove(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true, data: { id: 8, deleted: true } })
    );
  });

  it('rejects a caller who is not an influencer before ever running the query', async () => {
    (pool.query as jest.Mock).mockResolvedValue([{ affectedRows: 1 }]);
    const { req, res, next } = mockReqRes({
      user: { id: 1, role: 'brand', email: 'b@test.com', name: 'B' },
    });

    await socialController.remove(req, res, next);

    expect(pool.query).not.toHaveBeenCalled();
    const err = (next as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(403);
  });
});