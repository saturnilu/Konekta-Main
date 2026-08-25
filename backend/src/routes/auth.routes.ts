import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { requireAuth } from '../middlewares/auth';

const r = Router();
r.post('/register', authController.register);
r.post('/login', authController.login);
r.post('/logout', authController.logout);
r.post('/forgot-password', authController.forgot);
r.post('/reset-password', authController.resetPassword);
r.post('/change-password', requireAuth, authController.changePassword);
export default r;