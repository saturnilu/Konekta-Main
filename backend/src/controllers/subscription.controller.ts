import { Request, Response, NextFunction } from 'express';
import { subscriptionService } from '../services/subscription.service';
import { ok } from '../utils/response';
import { ApiError } from '../utils/apiError';

export const subscriptionController = {
  async plans(req: Request, res: Response, next: NextFunction) {
    try {
      const role = req.user?.role ?? 'brand';
      return ok(res, subscriptionService.getPlans(role));
    } catch (e) { next(e); }
  },

  async me(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      const data = await subscriptionService.getCurrent(req.user.id, req.user.role);
      return ok(res, data);
    } catch (e) { next(e); }
  },

  async subscribe(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      const planId = req.body?.plan_id ? Number(req.body.plan_id) : undefined;
      const planCode = req.body?.plan_code ? String(req.body.plan_code) : undefined;
      if (!planId && !planCode) throw new ApiError(400, 'plan_id or plan_code is required');
      const data = await subscriptionService.subscribe(req.user.id, req.user.role, planId, planCode);
      return ok(res, data, 'Subscribed');
    } catch (e) { next(e); }
  },

  async cancel(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      const data = await subscriptionService.cancel(req.user.id, req.user.role);
      return ok(res, data, 'Cancelled');
    } catch (e) { next(e); }
  },
};