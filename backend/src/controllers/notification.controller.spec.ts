import { Request, Response, NextFunction } from 'express';
import { notificationController } from './notification.controller';
import { notificationService } from '../services/notification.service';
import { ApiError } from '../utils/apiError';

jest.mock('../services/notification.service');

function mockReqRes(overrides: Partial<Request> = {}) {
  const req = {
    user: { id: 1, role: 'influencer', email: 'a@test.com', name: 'A' },
    params: { id: '5' },
    ...overrides,
  } as unknown as Request;
  const res = {
    json: jest.fn(),
    status: jest.fn().mockReturnThis(),
  } as unknown as Response;
  const next = jest.fn() as NextFunction;
  return { req, res, next };
}

describe('notificationController.markOneRead (regression: BUG-002)', () => {
  it("calls next with a 404 ApiError when the service reports 0 rows updated (not the caller's notification)", async () => {
    (notificationService.markOneRead as jest.Mock).mockResolvedValue({ updated: 0 });
    const { req, res, next } = mockReqRes();

    await notificationController.markOneRead(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const err = (next as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(404);
    expect(res.json).not.toHaveBeenCalled();
  });

  it('responds 200 when the service reports the notification was actually updated', async () => {
    (notificationService.markOneRead as jest.Mock).mockResolvedValue({ updated: 1 });
    const { req, res, next } = mockReqRes();

    await notificationController.markOneRead(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true, data: { updated: 1 } })
    );
  });

  it('rejects a non-numeric id with a 400 before touching the service', async () => {
    (notificationService.markOneRead as jest.Mock).mockResolvedValue({ updated: 1 });
    const { req, res, next } = mockReqRes({ params: { id: 'not-a-number' } });

    await notificationController.markOneRead(req, res, next);

    expect(notificationService.markOneRead).not.toHaveBeenCalled();
    const err = (next as jest.Mock).mock.calls[0][0];
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(400);
  });
});