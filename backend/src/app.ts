import express, { Request, Response } from 'express';
import path from 'path';
import cors from 'cors';
import authRoutes from './routes/auth.routes';
import profileRoutes from './routes/profile.routes';
import discoveryRoutes from './routes/discovery.routes';
import offerRoutes from './routes/offer.routes';
import videoRoutes from './routes/video.routes';
import chatRoutes from './routes/chat.routes';
import notificationRoutes from './routes/notification.routes';
import dashboardRoutes from './routes/dashboard.routes';
import googleAuthRoutes from './routes/googleAuth.routes';
import analyticsRoutes from './routes/analytics.routes';
import subscriptionRoutes from './routes/subscription.routes';
import socialRoutes from './routes/social.routes';
import withdrawalRoutes from './routes/withdrawal.routes';
import paymentMethodRoutes from './routes/payment_method.routes';
import { avatarUpload, avatarController } from './controllers/avatar.controller';
import { requireAuth } from './middlewares/auth';
import { errorHandler } from './middlewares/error';

export const app = express();

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : ['*'];

app.use(
  cors({
    origin: allowedOrigins.includes('*')
      ? '*'
      : (origin, cb) => {
          if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
          cb(new Error('CORS: origin not allowed'));
        },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

app.use(express.json({ limit: '5mb' }));

app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

const authHits = new Map<string, { count: number; resetAt: number }>();
function authRateLimit(req: Request, res: Response, next: () => void) {
  const ip = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ?? req.socket.remoteAddress ?? 'unknown';
  const now = Date.now();
  const window = 15 * 60 * 1000; 
  const maxReq = 20;
  const entry = authHits.get(ip);
  if (!entry || entry.resetAt < now) {
    authHits.set(ip, { count: 1, resetAt: now + window });
    return next();
  }
  entry.count += 1;
  if (entry.count > maxReq) {
    return res.status(429).json({ success: false, message: 'Too many requests, try again later' });
  }
  return next();
}

app.get('/health', (_req: Request, res: Response) =>
  res.json({ success: true, message: 'Konekta API is running' })
);

app.use('/auth', authRateLimit, authRoutes);
app.use('/auth', authRateLimit, googleAuthRoutes);
app.use('/profile', profileRoutes);
app.post('/profile/avatar', requireAuth, avatarUpload, avatarController.upload);
app.use('/', discoveryRoutes);        
app.use('/offers', offerRoutes);
app.use('/conversations', chatRoutes);
app.use('/notifications', notificationRoutes);
app.use('/dashboard', dashboardRoutes);
app.use('/subscriptions', subscriptionRoutes);
app.use('/analytics', analyticsRoutes);
app.use('/social', socialRoutes);
app.use('/withdrawals', withdrawalRoutes);
app.use('/payment-methods', paymentMethodRoutes);
app.use((_req: Request, res: Response) =>
  res.status(404).json({ success: false, message: 'Endpoint not found' })
);
app.use(errorHandler);