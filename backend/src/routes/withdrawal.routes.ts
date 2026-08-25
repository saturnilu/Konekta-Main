import { Router } from 'express';
import { withdrawalController } from '../controllers/withdrawal.controller';
import { requireAuth } from '../middlewares/auth';

const r = Router();
r.use(requireAuth);
r.get('/balance', withdrawalController.balance);
r.get('/mine', withdrawalController.mine);
r.post('/', withdrawalController.request);
export default r;