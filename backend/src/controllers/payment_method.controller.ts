import { Request, Response, NextFunction } from 'express';
import { paymentMethodService } from '../services/payment_method.service';
import { ok } from '../utils/response';
import { ApiError } from '../utils/apiError';

function requireBrand(req: Request) {
  if (!req.user) throw new ApiError(401, 'Unauthorized');
  if (req.user.role !== 'brand') throw new ApiError(403, 'Brands only');
  return req.user.id;
}

export const paymentMethodController = {
  async list(req: Request, res: Response, next: NextFunction) {
    try {
      const brandUserId = requireBrand(req);
      const data = await paymentMethodService.list(brandUserId);
      return ok(res, data);
    } catch (e) { next(e); }
  },

  async add(req: Request, res: Response, next: NextFunction) {
    try {
      const brandUserId = requireBrand(req);
      const { type, label, provider, last4, is_default } = req.body ?? {};
      const data = await paymentMethodService.add(brandUserId, { type, label, provider, last4, is_default });
      return ok(res, data, 'Payment method added');
    } catch (e) { next(e); }
  },

  async remove(req: Request, res: Response, next: NextFunction) {
    try {
      const brandUserId = requireBrand(req);
      const id = Number(req.params.id);
      const data = await paymentMethodService.remove(brandUserId, id);
      return ok(res, data, 'Payment method removed');
    } catch (e) { next(e); }
  },

  async setDefault(req: Request, res: Response, next: NextFunction) {
    try {
      const brandUserId = requireBrand(req);
      const id = Number(req.params.id);
      const data = await paymentMethodService.setDefault(brandUserId, id);
      return ok(res, data, 'Default payment method updated');
    } catch (e) { next(e); }
  },
};