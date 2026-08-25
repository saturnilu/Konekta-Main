import { pool, DbRow } from '../config/db';
import { ApiError } from '../utils/apiError';
import { notificationService } from './notification.service';

export type PlanRole = 'brand' | 'influencer';

export const BRAND_PLANS = [
  {
    plan_id: 1,
    plan_code: 'free',
    plan_name: 'Free',
    price: 0,
    currency: 'IDR',
    duration_months: null,
    description: 'For individuals just getting started',
    features: ['1 active campaign', 'Up to 20 influencer views', 'Basic analytics'],
  },
  {
    plan_id: 2,
    plan_code: 'starter',
    plan_name: 'Starter',
    price: 149000,
    currency: 'IDR',
    duration_months: 1,
    description: 'For growing brands',
    features: ['5 active campaigns', 'Unlimited influencer views', 'Standard analytics', 'In-app chat'],
  },
  {
    plan_id: 3,
    plan_code: 'pro',
    plan_name: 'Pro',
    price: 499000,
    currency: 'IDR',
    duration_months: 1,
    description: 'For professional teams',
    features: ['Unlimited campaigns', 'Priority support', 'Advanced analytics', 'Featured placement'],
  },
  {
    plan_id: 4,
    plan_code: 'enterprise',
    plan_name: 'Enterprise',
    price: 1499000,
    currency: 'IDR',
    duration_months: 12,
    description: 'For large organizations',
    features: ['Everything in Pro', 'Dedicated manager', 'Custom contracts', 'SSO & audit log'],
  },
];

export const INFLUENCER_PLANS = [
  {
    plan_id: 101,
    plan_code: 'free',
    plan_name: 'Free',
    price: 0,
    currency: 'IDR',
    duration_months: null,
    description: 'For creators just getting started',
    features: ['Apply to campaigns', '7-day analytics history', 'Standard listing in brand search'],
  },
  {
    plan_id: 102,
    plan_code: 'pro',
    plan_name: 'Pro Creator',
    price: 99000,
    currency: 'IDR',
    duration_months: 1,
    description: 'For creators who want to stand out',
    features: [
      'Verified Creator badge',
      'Featured placement in brand search',
      'Full analytics history (up to 1 year)',
    ],
  },
];

export const SUBSCRIPTION_PLANS = BRAND_PLANS;

function findPlan(plans: typeof BRAND_PLANS, planId?: number, planCode?: string) {
  if (planId) return plans.find((p) => p.plan_id === planId);
  if (planCode) return plans.find((p) => p.plan_code === planCode);
  return undefined;
}

function generateInvoiceNumber(userId: number): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  return `INV-${y}${m}-${userId}-${Date.now().toString().slice(-6)}`;
}

export const subscriptionService = {
  getPlans(role: PlanRole = 'brand') {
    return role === 'influencer' ? INFLUENCER_PLANS : BRAND_PLANS;
  },

  async getCurrent(userId: number, role: PlanRole) {
    return role === 'influencer' ? this.getCurrentInfluencer(userId) : this.getCurrentBrand(userId);
  },

  async _expireBrandIfNeeded(brandUserId: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT id, expires_at FROM brand_subscriptions
        WHERE brand_user_id = ? AND status = 'active'
        ORDER BY id DESC LIMIT 1`,
      [brandUserId]
    );
    const active = rows[0] as { id: number; expires_at: string | null } | undefined;
    if (!active || !active.expires_at) return;
    const [[nowRow]] = await pool.query<DbRow[]>(
      `SELECT (? <= NOW()) AS expired`, [active.expires_at]
    );
    if ((nowRow as { expired: number }).expired) {
      await pool.query(`UPDATE brand_subscriptions SET status = 'expired' WHERE id = ?`, [active.id]);
      await pool.query(`UPDATE brand_profiles SET plan = 'free' WHERE user_id = ?`, [brandUserId]);
    }
  },

  async _expireInfluencerIfNeeded(influencerUserId: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT plan, plan_expires_at, (plan_expires_at <= NOW()) AS is_expired
         FROM influencer_profiles WHERE user_id = ?`,
      [influencerUserId]
    );
    const row = rows[0] as { plan?: string; plan_expires_at?: string | null; is_expired?: number } | undefined;
    if (!row || row.plan !== 'pro' || !row.plan_expires_at) return;
    if (row.is_expired) {
      await pool.query(
        `UPDATE influencer_profiles SET plan = 'free', plan_expires_at = NULL WHERE user_id = ?`,
        [influencerUserId]
      );
      await pool.query(`UPDATE users SET is_verified = 0 WHERE id = ?`, [influencerUserId]);
    }
  },

  async getCurrentBrand(brandUserId: number) {
    await this._expireBrandIfNeeded(brandUserId);
    const [rows] = await pool.query<DbRow[]>(
      `SELECT id, plan_id, plan_code, plan_name, status, started_at, expires_at
         FROM brand_subscriptions
        WHERE brand_user_id = ? AND status = 'active'
        ORDER BY id DESC
        LIMIT 1`,
      [brandUserId]
    );
    const active = rows[0] as Record<string, unknown> | undefined;
    if (!active) {
      return {
        plan_id: 1,
        plan_name: 'Free',
        plan_code: 'free',
        status: 'active',
        expires_at: null,
        started_at: null,
      };
    }
    return {
      plan_id: active.plan_id ?? 1,
      plan_name: active.plan_name ?? 'Free',
      plan_code: active.plan_code ?? 'free',
      status: active.status ?? 'active',
      expires_at: active.expires_at ?? null,
      started_at: active.started_at ?? null,
    };
  },

  async getCurrentInfluencer(influencerUserId: number) {
    await this._expireInfluencerIfNeeded(influencerUserId);
    const [rows] = await pool.query<DbRow[]>(
      `SELECT plan, plan_expires_at FROM influencer_profiles WHERE user_id = ?`,
      [influencerUserId]
    );
    const row = rows[0] as { plan?: string; plan_expires_at?: string | null } | undefined;
    const planCode = row?.plan ?? 'free';
    const plan = INFLUENCER_PLANS.find((p) => p.plan_code === planCode) ?? INFLUENCER_PLANS[0];
    return {
      plan_id: plan.plan_id,
      plan_name: plan.plan_name,
      plan_code: plan.plan_code,
      status: 'active',
      expires_at: row?.plan_expires_at ?? null,
      started_at: null,
    };
  },

  async subscribe(userId: number, role: PlanRole, planId?: number, planCode?: string) {
    return role === 'influencer'
      ? this.subscribeInfluencer(userId, planId, planCode)
      : this.subscribeBrand(userId, planId, planCode);
  },

  async subscribeBrand(brandUserId: number, planId?: number, planCode?: string) {
    const plan = findPlan(BRAND_PLANS, planId, planCode);
    if (!plan) throw new ApiError(400, 'Unknown plan');

    await this._expireBrandIfNeeded(brandUserId);

    if (plan.price === 0) {
      const current = await this.getCurrentBrand(brandUserId);
      if (current.plan_code !== 'free' && current.expires_at) {
        const until = new Date(String(current.expires_at)).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
        throw new ApiError(
          400,
          `Your ${current.plan_name} plan is active until ${until}. It will automatically switch to Free after that — no need to downgrade manually.`
        );
      }
    }

    await pool.query(
      `UPDATE brand_subscriptions SET status = 'cancelled', cancelled_at = NOW()
        WHERE brand_user_id = ? AND status = 'active'`,
      [brandUserId]
    );

    const durationDays = plan.duration_months ? plan.duration_months * 30 : null;
    const [r] = await pool.query(
      `INSERT INTO brand_subscriptions
         (brand_user_id, plan_id, plan_code, plan_name, status, started_at, expires_at)
       VALUES (?, ?, ?, ?, 'active', NOW(), ${durationDays ? `DATE_ADD(NOW(), INTERVAL ${durationDays} DAY)` : 'NULL'})`,
      [brandUserId, plan.plan_id, plan.plan_code, plan.plan_name]
    );

    const planEnumMap: Record<string, string> = {
      free: 'free',
      starter: 'pro_monthly',
      pro: 'pro_monthly',
      enterprise: 'pro_annual',
    };
    const planEnum = planEnumMap[plan.plan_code] ?? 'free';
    await pool.query(
      `UPDATE brand_profiles SET plan = ? WHERE user_id = ?`,
      [planEnum, brandUserId]
    );

    const invoiceNumber = generateInvoiceNumber(brandUserId);
    const [[fresh]] = await pool.query<DbRow[]>(
      `SELECT started_at, expires_at FROM brand_subscriptions WHERE id = ?`,
      [(r as { insertId: number }).insertId]
    );
    const { started_at, expires_at } = fresh as { started_at: string; expires_at: string | null };

    if (plan.price > 0) {
      try {
        await notificationService.push(brandUserId, {
          type: 'subscription',
          title: `Welcome to ${plan.plan_name}!`,
          body: expires_at
            ? `Your ${plan.plan_name} plan is active until ${new Date(expires_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })}.`
            : `Your ${plan.plan_name} plan is now active.`,
          data: { plan_code: plan.plan_code, invoice_number: invoiceNumber },
        });
      } catch {  }
    }

    return {
      id: (r as { insertId: number }).insertId,
      plan_id: plan.plan_id,
      plan_name: plan.plan_name,
      plan_code: plan.plan_code,
      status: 'active',
      started_at,
      expires_at,
      amount: plan.price,
      currency: plan.currency,
      invoice_number: invoiceNumber,
    };
  },

  async subscribeInfluencer(influencerUserId: number, planId?: number, planCode?: string) {
    const plan = findPlan(INFLUENCER_PLANS, planId, planCode);
    if (!plan) throw new ApiError(400, 'Unknown plan');

    await this._expireInfluencerIfNeeded(influencerUserId);

    if (plan.price === 0) {
      const current = await this.getCurrentInfluencer(influencerUserId);
      if (current.plan_code !== 'free' && current.expires_at) {
        const until = new Date(String(current.expires_at)).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
        throw new ApiError(
          400,
          `Your ${current.plan_name} plan is active until ${until}. It will automatically switch to Free after that — no need to downgrade manually.`
        );
      }
    }

    const durationDays = plan.duration_months ? plan.duration_months * 30 : null;
    await pool.query(
      `UPDATE influencer_profiles
          SET plan = ?, plan_expires_at = ${durationDays ? `DATE_ADD(NOW(), INTERVAL ${durationDays} DAY)` : 'NULL'}
        WHERE user_id = ?`,
      [plan.plan_code, influencerUserId]
    );

    await pool.query(
      `UPDATE users SET is_verified = ? WHERE id = ?`,
      [plan.plan_code === 'pro' ? 1 : 0, influencerUserId]
    );

    const [[fresh]] = await pool.query<DbRow[]>(
      `SELECT plan_expires_at FROM influencer_profiles WHERE user_id = ?`,
      [influencerUserId]
    );
    const expiresAt = (fresh as { plan_expires_at: string | null }).plan_expires_at;
    const invoiceNumber = generateInvoiceNumber(influencerUserId);

    if (plan.price > 0) {
      try {
        await notificationService.push(influencerUserId, {
          type: 'subscription',
          title: `Welcome to ${plan.plan_name}!`,
          body: expiresAt
            ? `Your ${plan.plan_name} plan is active until ${new Date(expiresAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })}. Your Verified badge is now live!`
            : `Your ${plan.plan_name} plan is now active.`,
          data: { plan_code: plan.plan_code, invoice_number: invoiceNumber },
        });
      } catch {  }
    }

    return {
      plan_id: plan.plan_id,
      plan_name: plan.plan_name,
      plan_code: plan.plan_code,
      status: 'active',
      started_at: new Date().toISOString(),
      expires_at: expiresAt,
      amount: plan.price,
      currency: plan.currency,
      invoice_number: invoiceNumber,
    };
  },

  async cancel(userId: number, role: PlanRole) {
    return role === 'influencer' ? this.cancelInfluencer(userId) : this.cancelBrand(userId);
  },

  async cancelBrand(brandUserId: number) {
    await this._expireBrandIfNeeded(brandUserId);
    const current = await this.getCurrentBrand(brandUserId);
    if (current.plan_code === 'free') {
      throw new ApiError(404, 'No active subscription to cancel');
    }
    if (current.expires_at) {
      const until = new Date(String(current.expires_at)).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
      throw new ApiError(
        400,
        `Your ${current.plan_name} plan is active until ${until}. It will automatically switch to Free after that.`
      );
    }
    await pool.query(
      `UPDATE brand_subscriptions SET status = 'cancelled', cancelled_at = NOW()
        WHERE brand_user_id = ? AND status = 'active'`,
      [brandUserId]
    );
    await pool.query(`UPDATE brand_profiles SET plan = 'free' WHERE user_id = ?`, [brandUserId]);
    return { cancelled: true };
  },

  async cancelInfluencer(influencerUserId: number) {
    await this._expireInfluencerIfNeeded(influencerUserId);
    const current = await this.getCurrentInfluencer(influencerUserId);
    if (current.plan_code === 'free') {
      throw new ApiError(404, 'No active subscription to cancel');
    }
    if (current.expires_at) {
      const until = new Date(String(current.expires_at)).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
      throw new ApiError(
        400,
        `Your ${current.plan_name} plan is active until ${until}. It will automatically switch to Free after that.`
      );
    }
    await pool.query(`UPDATE influencer_profiles SET plan = 'free', plan_expires_at = NULL WHERE user_id = ?`, [influencerUserId]);
    await pool.query(`UPDATE users SET is_verified = 0 WHERE id = ?`, [influencerUserId]);
    return { cancelled: true };
  },
};