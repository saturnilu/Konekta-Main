import { Router } from 'express';
import { chatController } from '../controllers/chat.controller';
import { requireAuth } from '../middlewares/auth';

const r = Router();
r.use(requireAuth);
r.get('/', chatController.list);
r.post('/', chatController.create);         
r.post('/ensure', chatController.ensure);   
r.get('/:id/messages', chatController.messages);
r.post('/:id/messages', chatController.send);
export default r;
