import { Router, Request, Response } from 'express';
import { SessionManager } from '../sessionManager';
import {
  CreateSessionRequest,
  NavigateRequest,
  TapRequest,
  ScrollRequest,
  TextInputRequest,
  ErrorResponse,
} from '../types';

export function createSessionsRouter(manager: SessionManager): Router {
  const router = Router();

  // Helper: extract and validate Bearer token from Authorization header
  function extractToken(req: Request): string | null {
    const auth = req.headers['authorization'];
    if (!auth || !auth.startsWith('Bearer ')) return null;
    return auth.slice(7);
  }

  // Helper: send a typed error response
  function sendError(res: Response, status: number, code: string, message: string): void {
    const body: ErrorResponse = { error: message, code };
    res.status(status).json(body);
  }

  // Middleware: authenticate session token
  function requireAuth(req: Request, res: Response, next: () => void): void {
    const { id } = req.params;
    if (!manager.hasSession(id)) {
      sendError(res, 404, 'SESSION_NOT_FOUND', 'Session not found');
      return;
    }
    const token = extractToken(req);
    if (!token || !manager.validateToken(id, token)) {
      sendError(res, 401, 'UNAUTHORIZED', 'Invalid or missing session token');
      return;
    }
    next();
  }

  // POST /sessions — create a new remote browser session
  router.post('/', async (req: Request, res: Response) => {
    const body = req.body as CreateSessionRequest;
    const viewportWidth =
      typeof body.viewportWidth === 'number' && body.viewportWidth > 0
        ? body.viewportWidth
        : 320;
    const viewportHeight =
      typeof body.viewportHeight === 'number' && body.viewportHeight > 0
        ? body.viewportHeight
        : 568;
    const initialUrl = typeof body.url === 'string' ? body.url : undefined;

    try {
      const result = await manager.createSession(viewportWidth, viewportHeight, initialUrl);
      res.status(201).json({
        sessionId: result.id,
        token: result.token,
        viewportWidth: result.viewportWidth,
        viewportHeight: result.viewportHeight,
      });
    } catch (err) {
      sendError(res, 500, 'SESSION_CREATE_FAILED', (err as Error).message);
    }
  });

  // POST /sessions/:id/navigate — navigate to a URL
  router.post('/:id/navigate', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    const body = req.body as NavigateRequest;
    if (!body.url || typeof body.url !== 'string') {
      sendError(res, 400, 'INVALID_PAYLOAD', 'url is required');
      return;
    }

    try {
      await manager.navigate(id, body.url);
      res.json({ ok: true });
    } catch (err) {
      sendError(res, 502, 'NAVIGATION_FAILED', (err as Error).message);
    }
  });

  // GET /sessions/:id/frame — get current frame as JPEG
  router.get('/:id/frame', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    try {
      const frame = await manager.getFrame(id);
      res.set('Content-Type', 'image/jpeg');
      res.set('Cache-Control', 'no-store');
      res.send(frame);
    } catch (err) {
      sendError(res, 500, 'FRAME_FAILED', (err as Error).message);
    }
  });

  // POST /sessions/:id/input/tap — send a tap/click
  router.post('/:id/input/tap', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    const body = req.body as TapRequest;
    if (typeof body.x !== 'number' || typeof body.y !== 'number') {
      sendError(res, 400, 'INVALID_PAYLOAD', 'x and y are required numbers');
      return;
    }

    try {
      await manager.tap(id, body.x, body.y);
      res.json({ ok: true });
    } catch (err) {
      sendError(res, 500, 'TAP_FAILED', (err as Error).message);
    }
  });

  // POST /sessions/:id/input/scroll — send a scroll event
  router.post('/:id/input/scroll', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    const body = req.body as ScrollRequest;
    if (
      typeof body.x !== 'number' ||
      typeof body.y !== 'number' ||
      typeof body.deltaX !== 'number' ||
      typeof body.deltaY !== 'number'
    ) {
      sendError(res, 400, 'INVALID_PAYLOAD', 'x, y, deltaX, and deltaY are required numbers');
      return;
    }

    try {
      await manager.scroll(id, body.x, body.y, body.deltaX, body.deltaY);
      res.json({ ok: true });
    } catch (err) {
      sendError(res, 500, 'SCROLL_FAILED', (err as Error).message);
    }
  });

  // POST /sessions/:id/input/text — send text input
  router.post('/:id/input/text', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    const body = req.body as TextInputRequest;
    if (!body.text || typeof body.text !== 'string') {
      sendError(res, 400, 'INVALID_PAYLOAD', 'text is required');
      return;
    }

    try {
      await manager.typeText(id, body.text);
      res.json({ ok: true });
    } catch (err) {
      sendError(res, 500, 'TEXT_INPUT_FAILED', (err as Error).message);
    }
  });

  // GET /sessions/:id/state — get session state
  router.get('/:id/state', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    try {
      const state = await manager.getState(id);
      res.json(state);
    } catch (err) {
      sendError(res, 500, 'STATE_FAILED', (err as Error).message);
    }
  });

  // DELETE /sessions/:id — close and destroy the session
  router.delete('/:id', requireAuth, async (req: Request, res: Response) => {
    const { id } = req.params;
    try {
      await manager.deleteSession(id);
      res.json({ ok: true });
    } catch (err) {
      sendError(res, 500, 'SESSION_DELETE_FAILED', (err as Error).message);
    }
  });

  return router;
}
