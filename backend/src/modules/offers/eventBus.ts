import { pool } from '../../config/db';

export interface DomainEvent {
  type: string;
  payload: Record<string, any>;
  timestamp: Date;
  metadata?: Record<string, any>;
}

type EventHandler = (event: DomainEvent) => Promise<void> | void;

class EventBus {
  private subscribers: Map<string, EventHandler[]> = new Map();

  subscribe(eventType: string, handler: EventHandler): void {
    if (!this.subscribers.has(eventType)) {
      this.subscribers.set(eventType, []);
    }
    this.subscribers.get(eventType)!.push(handler);
  }

  unsubscribe(eventType: string, handler: EventHandler): void {
    const handlers = this.subscribers.get(eventType);
    if (!handlers) return;
    const idx = handlers.indexOf(handler);
    if (idx !== -1) handlers.splice(idx, 1);
  }

  async publish(eventType: string, payload: Record<string, any>): Promise<void> {
    const event: DomainEvent = {
      type: eventType,
      payload,
      timestamp: new Date(),
    };

    const handlers = this.subscribers.get(eventType) ?? [];
    const allHandlers: EventHandler[] = [...handlers];

    const wildcardHandlers = this.subscribers.get('*') ?? [];
    allHandlers.push(...wildcardHandlers);

    if (allHandlers.length === 0) return;

    const results = await Promise.allSettled(
      allHandlers.map(async (h) => {
        try {
          await h(event);
        } catch (err) {
          console.error(`[EventBus] handler for ${eventType} failed:`, err);
          throw err;
        }
      })
    );

    const failed = results.filter((r) => r.status === 'rejected');
    if (failed.length) {
      console.warn(`[EventBus] ${failed.length}/${results.length} handlers failed for ${eventType}`);
    }
  }

  getSubscribers(eventType: string): number {
    return this.subscribers.get(eventType)?.length ?? 0;
  }

  clear(): void {
    this.subscribers.clear();
  }
}

export const eventBus = new EventBus();

eventBus.subscribe('campaign.created', async (event) => {
  const { user_id, title } = event.payload;
  if (!user_id) return;
  await pool.query(
    `INSERT INTO notifications (user_id, type, title, body, icon)
     VALUES (?, 'campaign', ?, ?, 'campaign')`,
    [user_id, 'New Campaign', title ?? 'New campaign available']
  );
});

eventBus.subscribe('campaign.status_changed', async (event) => {
  const { user_id, title, from_state, to_state } = event.payload;
  if (!user_id) return;
  await pool.query(
    `INSERT INTO notifications (user_id, type, title, body, icon)
     VALUES (?, 'status', ?, ?, 'sync')`,
    [user_id, `Campaign ${to_state}`, `${title} transitioned from ${from_state} to ${to_state}`]
  );
});

eventBus.subscribe('*', async (event) => {
  await pool.query(
    `INSERT INTO analytics_logs (event_type, payload, created_at)
     VALUES (?, ?, NOW())`,
    [event.type, JSON.stringify(event.payload)]
  ).catch((err) => {
    console.warn('[analyticsSubscriber]', err.message);
  });
});

eventBus.subscribe('campaign.created', async (event) => {
  const { user_id, offer_id } = event.payload;
  await pool.query(
    `INSERT INTO activity_logs (user_id, action, resource_type, resource_id, created_at)
     VALUES (?, 'create', 'offer', ?, NOW())`,
    [user_id, offer_id]
  ).catch((err) => {
    console.warn('[activityLogSubscriber]', err.message);
  });
});

eventBus.subscribe('campaign.status_changed', async (event) => {
  const { user_id, offer_id, from_state, to_state } = event.payload;
  await pool.query(
    `INSERT INTO activity_logs (user_id, action, resource_type, resource_id, metadata, created_at)
     VALUES (?, 'update_status', 'offer', ?, ?, NOW())`,
    [user_id, offer_id, JSON.stringify({ from: from_state, to: to_state })]
  ).catch((err) => {
    console.warn('[activityLogSubscriber]', err.message);
  });
});

export default eventBus;
