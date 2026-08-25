import { Router } from 'express';
import { offerController } from '../controllers/offer.controller';
import { requireAuth } from '../middlewares/auth';
import videoRoutes from './video.routes';

const r = Router();

r.get('/', offerController.listPublic);

r.get('/mine', requireAuth, offerController.listMine);
r.get('/applications/mine', requireAuth, offerController.myApplications);

r.post('/', requireAuth, offerController.create);
r.get('/:id', offerController.detail); // public
r.put('/:id', requireAuth, offerController.update);
r.get('/:id/applicants', requireAuth, offerController.listApplicants);
r.get('/:id/applicants/:appId', requireAuth, offerController.getApplicant);
r.patch('/:id/applicants/:appId/status', requireAuth, offerController.setApplicationStatus);

r.post('/:id/apply', requireAuth, offerController.apply);
r.post('/:id/applicants', requireAuth, offerController.apply);

r.post('/:id/progress', requireAuth, offerController.addProgress);
r.get('/:id/progress', requireAuth, offerController.getProgress);

r.use('/:id/videos', videoRoutes);

export default r;
