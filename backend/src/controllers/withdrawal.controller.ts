import { Request, Response, NextFunction } from 'express';
import { withdrawalService } from '../services/withdrawal.service';
import { ok } from '../utils/response';
import { ApiError } from '../utils/apiError';

export const withdrawalController = {
  async balance(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      if (req.user.role !== 'influencer') throw new ApiError(403, 'Influencers only');
      const data = await withdrawalService.getBalance(req.user.id);
      return ok(res, data);
    } catch (e) { next(e); }
  },

  async request(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      if (req.user.role !== 'influencer') throw new ApiError(403, 'Influencers only');
      const { amount, bank_name, account_number, account_name } = req.body ?? {};
      const data = await withdrawalService.requestWithdrawal(req.user.id, {
        amount, bank_name, account_number, account_name,
      });
      return ok(res, data, 'Withdrawal request submitted');
    } catch (e) { next(e); }
  },

  async mine(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      if (req.user.role !== 'influencer') throw new ApiError(403, 'Influencers only');
      const data = await withdrawalService.listMine(req.user.id);
      return ok(res, data);
    } catch (e) { next(e); }
  },
};