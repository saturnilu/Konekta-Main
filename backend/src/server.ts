import { app } from './app';
import { env } from './config/env';
import { pingDb } from './config/db';

async function bootstrap() {
  try {
    await pingDb();
    console.log('[db] connected');
  } catch (err) {
    console.warn('[db] could not connect — server still starting', err);
  }
  app.listen(env.port, () => {
    console.log(`[konekta] api listening on http://localhost:${env.port}`);
  });
}

bootstrap();
