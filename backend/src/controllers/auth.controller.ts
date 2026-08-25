import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authService } from '../services/auth.service';
import { ok, created } from '../utils/response';
import { ApiError } from '../utils/apiError';

const registerSchema = z.object({
  name: z.string().min(2).max(120),
  email: z.string().email(),
  password: z.string().min(6).max(120),
  role: z.enum(['influencer', 'brand']),
  username: z.string().min(2).max(80).optional(),
  brand_name: z.string().min(2).max(120).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export const authController = {
  async register(req: Request, res: Response, next: NextFunction) {
    try {
      const data = registerSchema.parse(req.body);
      const result = await authService.register(data);
      return created(res, result, 'Account created');
    } catch (e) {
      next(e);
    }
  },
  async login(req: Request, res: Response, next: NextFunction) {
    try {
      const data = loginSchema.parse(req.body);
      const result = await authService.login(data.email, data.password);
      return ok(res, result, 'Logged in');
    } catch (e) {
      next(e);
    }
  },
  async logout(_req: Request, res: Response) {
    return ok(res, null, 'Logged out');
  },
  async forgot(req: Request, res: Response, next: NextFunction) {
    try {
      const { email } = z.object({ email: z.string().email() }).parse(req.body);
      const result = await authService.forgotPassword(email);
      return ok(res, result, 'If the email exists, a reset link has been sent');
    } catch (e) {
      next(e);
    }
  },
  async resetPassword(req: Request, res: Response, next: NextFunction) {
    try {
      const { token, password } = z.object({
        token: z.string().min(10),
        password: z.string().min(6).max(120),
      }).parse(req.body);
      const result = await authService.resetPassword(token, password);
      return ok(res, result, 'Password updated — you can log in now');
    } catch (e) {
      next(e);
    }
  },
  async changePassword(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthorized');
      const { current_password, new_password } = z.object({
        current_password: z.string().min(1),
        new_password: z.string().min(6).max(120),
      }).parse(req.body);
      const result = await authService.changePassword(req.user.id, current_password, new_password);
      return ok(res, result, 'Password changed');
    } catch (e) {
      next(e);
    }
  },
};