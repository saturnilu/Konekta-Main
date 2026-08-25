import { Request, Response, NextFunction } from 'express';
import { dashboardService } from '../services/dashboard.service';
import { ok } from '../utils/response';
import { ApiError } from '../utils/apiError';
import { pool } from '../config/db';
import { refreshAllVideosForUser } from '../services/video_stats.service';

export const dashboardController = {
  async overview(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthenticated');

      if (req.user.role === 'influencer') {
        try { await refreshAllVideosForUser(req.user.id); } catch {  }
      } else {
        try {
          const [influencerRows] = await pool.query<import('../config/db').DbRow[]>(
            `SELECT DISTINCT ca.influencer_user_id
               FROM campaign_applicants ca
               JOIN offers o ON o.id = ca.offer_id
              WHERE o.brand_user_id = ? AND ca.status IN ('approved','completed')`,
            [req.user.id]
          );
          await Promise.allSettled(
            influencerRows.map((r) =>
              refreshAllVideosForUser((r as { influencer_user_id: number }).influencer_user_id)
            )
          );
        } catch {  }
      }

      const data = req.user.role === 'brand'
        ? await dashboardService.brandOverview(req.user.id)
        : await dashboardService.influencerOverview(req.user.id);
      return ok(res, data);
    } catch (e) { next(e); }
  },

  async influencer(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthenticated');
      if (req.user.role !== 'influencer') throw new ApiError(403, 'Influencers only');

      try { await refreshAllVideosForUser(req.user.id); } catch {  }

      const data = await dashboardService.influencerOverview(req.user.id);
      return ok(res, data);
    } catch (e) { next(e); }
  },

  async brand(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthenticated');
      if (req.user.role !== 'brand') throw new ApiError(403, 'Brands only');

      try {
        const [influencerRows] = await pool.query<import('../config/db').DbRow[]>(
          `SELECT DISTINCT ca.influencer_user_id
             FROM campaign_applicants ca
             JOIN offers o ON o.id = ca.offer_id
            WHERE o.brand_user_id = ? AND ca.status IN ('approved','completed')`,
          [req.user.id]
        );
        await Promise.allSettled(
          influencerRows.map((r) =>
            refreshAllVideosForUser((r as { influencer_user_id: number }).influencer_user_id)
          )
        );
      } catch {  }

      const data = await dashboardService.brandOverview(req.user.id);
      return ok(res, data);
    } catch (e) { next(e); }
  },

  async brandTransactions(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new ApiError(401, 'Unauthenticated');
      if (req.user.role !== 'brand') throw new ApiError(403, 'Brands only');
      const page = Math.max(1, Number(req.query.page) || 1);
      const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
      const data = await dashboardService.brandTransactions(req.user.id, page, limit);
      return ok(res, data);
    } catch (e) { next(e); }
  },
};