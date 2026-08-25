import { pool, DbRow } from '../../config/db';
import { ApiError } from '../../core/utils/apiError';

export type CampaignStateName =
  | 'draft' | 'open' | 'offered' | 'negotiation'
  | 'accepted' | 'in_progress' | 'submitted' | 'completed'
  | 'rejected' | 'cancelled';

interface CampaignStateContext {
  offerId: number;
  userId: number;
  title: string;
}

export interface CampaignState {
  name: CampaignStateName;
  transitions: CampaignStateName[];
  onEnter?(ctx: CampaignStateContext): Promise<void>;
  canTransition?(ctx: CampaignStateContext, target: CampaignStateName): boolean;
}

const CampaignStates: Record<CampaignStateName, CampaignState> = {
  draft: {
    name: 'draft',
    transitions: ['open', 'rejected', 'cancelled'],
  },
  open: {
    name: 'open',
    transitions: ['offered', 'rejected', 'cancelled'],
  },
  offered: {
    name: 'offered',
    transitions: ['negotiation', 'accepted', 'rejected', 'cancelled'],
  },
  negotiation: {
    name: 'negotiation',
    transitions: ['accepted', 'rejected', 'cancelled'],
  },
  accepted: {
    name: 'accepted',
    transitions: ['in_progress', 'rejected', 'cancelled'],
  },
  in_progress: {
    name: 'in_progress',
    transitions: ['submitted', 'cancelled'],
  },
  submitted: {
    name: 'submitted',
    transitions: ['completed', 'rejected'],
  },
  completed: {
    name: 'completed',
    transitions: [], // terminal
  },
  rejected: {
    name: 'rejected',
    transitions: [], 
  },
  cancelled: {
    name: 'cancelled',
    transitions: [], 
  },
};

export class CampaignStateMachine {
  private states = CampaignStates;

  getValidTransitions(current: CampaignStateName): CampaignStateName[] {
    return this.states[current]?.transitions ?? [];
  }

  isValidTransition(current: CampaignStateName, target: CampaignStateName): boolean {
    const allowed = this.getValidTransitions(current);
    return allowed.includes(target);
  }

  async transition(
    offerId: number,
    userId: number,
    fromState: CampaignStateName,
    toState: CampaignStateName
  ): Promise<{ success: boolean; error?: string }> {
    if (!this.isValidTransition(fromState, toState)) {
      const allowed = this.getValidTransitions(fromState);
      return {
        success: false,
        error: `Cannot transition from ${fromState} to ${toState}. Allowed: ${allowed.join(', ') || 'none (terminal state)'}`,
      };
    }

    const [rows] = await pool.query<DbRow[]>(
      'SELECT brand_user_id, influencer_user_id, title FROM offers WHERE id = ?',
      [offerId]
    );
    if (!rows.length) {
      return { success: false, error: 'Offer not found' };
    }

    const offer = rows[0] as { brand_user_id: number; influencer_user_id: number; title: string };
    if (userId !== offer.brand_user_id && userId !== offer.influencer_user_id) {
      return { success: false, error: 'Not authorized' };
    }

    await pool.query('UPDATE offers SET status = ? WHERE id = ?', [toState, offerId]);

    const notifyUser = userId === offer.brand_user_id
      ? offer.influencer_user_id
      : offer.brand_user_id;

    await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, icon)
       VALUES (?, 'status', ?, ?, 'sync')`,
      [notifyUser, 'Campaign Status Updated', `${offer.title} → ${toState}`]
    );

    const stateDef = this.states[toState];
    if (stateDef?.onEnter) {
      await stateDef.onEnter({ offerId, userId, title: offer.title });
    }

    return { success: true };
  }
}

export type ApplicationStateName =
  | 'pending' | 'approved' | 'rejected' | 'completed';

export interface ApplicationState {
  name: ApplicationStateName;
  transitions: ApplicationStateName[];
  onEnter?(ctx: CampaignStateContext): Promise<void>;
  canTransition?(ctx: CampaignStateContext, target: ApplicationStateName): boolean;
}

const ApplicationStates: Record<ApplicationStateName, ApplicationState> = {
  pending: {
    name: 'pending',
    transitions: ['approved', 'rejected'],
  },
  approved: {
    name: 'approved',
    transitions: ['completed', 'rejected'],
  },
  rejected: {
    name: 'rejected',
    transitions: [],
  },
  completed: {
    name: 'completed',
    transitions: [],
  },
};

export class ApplicationStateMachine {
  private states = ApplicationStates;

  getValidTransitions(current: ApplicationStateName): ApplicationStateName[] {
    return (this.states[current]?.transitions as ApplicationStateName[]) ?? [];
  }

  isValidTransition(current: ApplicationStateName, target: ApplicationStateName): boolean {
    return this.getValidTransitions(current).includes(target);
  }

  async transition(
    applicantId: number,
    userId: number,
    fromState: ApplicationStateName,
    toState: ApplicationStateName
  ): Promise<{ success: boolean; error?: string }> {
    if (!this.isValidTransition(fromState, toState)) {
      const allowed = this.getValidTransitions(fromState);
      return {
        success: false,
        error: `Cannot transition from ${fromState} to ${toState}. Allowed: ${allowed.join(', ') || 'none (terminal state)'}`,
      };
    }

    const [rows] = await pool.query<DbRow[]>(
      `SELECT ca.offer_id, ca.influencer_user_id,
              o.brand_user_id
       FROM campaign_applicants ca
       JOIN offers o ON o.id = ca.offer_id
       WHERE ca.id = ?`,
      [applicantId]
    );

    if (!rows.length) {
      return { success: false, error: 'Applicant not found' };
    }

    const row = rows[0] as { offer_id: number; influencer_user_id: number; brand_user_id: number };

    if (userId !== row.brand_user_id) {
      return { success: false, error: 'Only the brand can update application status' };
    }

    await pool.query(
      'UPDATE campaign_applicants SET status = ? WHERE id = ?',
      [toState, applicantId]
    );

    if (toState === 'approved' || toState === 'completed') {
      await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, icon)
         VALUES (?, 'application', ?, ?, 'task_alt')`,
        [row.influencer_user_id, `Application ${toState}`, `Your application for offer #${row.offer_id} was ${toState}`]
      );
    }

    return { success: true };
  }
}
