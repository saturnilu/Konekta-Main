import { Router } from 'express';
import { paymentMethodController } from '../controllers/payment_method.controller';
import { requireAuth } from '../middlewares/auth';

const r = Router();
r.use(requireAuth);
r.get('/mine', paymentMethodController.list);
r.post('/', paymentMethodController.add);
r.delete('/:id', paymentMethodController.remove);
r.post('/:id/default', paymentMethodController.setDefault);
export default r;