import express from 'express';
import { SessionManager } from './sessionManager';
import { createSessionsRouter } from './routes/sessions';

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;

async function main(): Promise<void> {
  const app = express();
  app.use(express.json());

  const manager = new SessionManager();
  await manager.init();

  app.use('/sessions', createSessionsRouter(manager));

  // Health check
  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  // Graceful shutdown
  const server = app.listen(PORT, () => {
    console.log(`5sAvailator server listening on port ${PORT}`);
  });

  const shutdown = async () => {
    console.log('Shutting down...');
    server.close();
    await manager.close();
    process.exit(0);
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
