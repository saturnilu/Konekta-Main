import { Router } from 'express';
import { subscriptionController } from '../controllers/subscription.controller';
import { requireAuth, optionalAuth } from '../middlewares/auth';

const r = Router();
r.get('/plans', optionalAuth, subscriptionController.plans);
r.get('/me', requireAuth, subscriptionController.me);
r.post('/subscribe', requireAuth, subscriptionController.subscribe);
r.post('/cancel', requireAuth, subscriptionController.cancel);
export default r;