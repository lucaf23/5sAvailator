import { chromium, Browser, BrowserContext, Page } from 'playwright';
import { v4 as uuidv4 } from 'uuid';
import { Session, SessionState } from './types';

// Default viewport matches iPhone 5s logical resolution for remote rendering
const DEFAULT_VIEWPORT_WIDTH = 320;
const DEFAULT_VIEWPORT_HEIGHT = 568;

// Session idle timeout: 10 minutes
const SESSION_IDLE_TIMEOUT_MS = 10 * 60 * 1000;

// Cleanup check interval: 1 minute
const CLEANUP_INTERVAL_MS = 60 * 1000;

interface InternalSession {
  meta: Session;
  context: BrowserContext;
  page: Page;
}

export class SessionManager {
  private browser: Browser | null = null;
  private sessions: Map<string, InternalSession> = new Map();
  private cleanupTimer: ReturnType<typeof setInterval> | null = null;

  async init(): Promise<void> {
    this.browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    this.cleanupTimer = setInterval(() => {
      this.cleanupIdleSessions();
    }, CLEANUP_INTERVAL_MS);
  }

  async createSession(
    viewportWidth: number = DEFAULT_VIEWPORT_WIDTH,
    viewportHeight: number = DEFAULT_VIEWPORT_HEIGHT,
    initialUrl?: string
  ): Promise<{ id: string; token: string; viewportWidth: number; viewportHeight: number }> {
    if (!this.browser) {
      throw new Error('Browser not initialized');
    }

    const id = uuidv4();
    const token = uuidv4();
    const now = Date.now();

    const context = await this.browser.newContext({
      viewport: { width: viewportWidth, height: viewportHeight },
      userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    });
    const page = await context.newPage();

    const meta: Session = {
      id,
      token,
      url: null,
      createdAt: now,
      lastActivityAt: now,
      viewportWidth,
      viewportHeight,
    };

    this.sessions.set(id, { meta, context, page });

    if (initialUrl) {
      await this.navigate(id, initialUrl);
    }

    return { id, token, viewportWidth, viewportHeight };
  }

  async navigate(id: string, url: string): Promise<void> {
    const session = this.getSessionOrThrow(id);
    try {
      await session.page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      session.meta.url = session.page.url();
      session.meta.lastActivityAt = Date.now();
    } catch (err) {
      throw new Error(`Navigation failed: ${(err as Error).message}`);
    }
  }

  async getFrame(id: string): Promise<Buffer> {
    const session = this.getSessionOrThrow(id);
    try {
      const screenshot = await session.page.screenshot({
        type: 'jpeg',
        quality: 75,
        fullPage: false,
      });
      session.meta.lastActivityAt = Date.now();
      return screenshot;
    } catch (err) {
      throw new Error(`Screenshot failed: ${(err as Error).message}`);
    }
  }

  async tap(id: string, x: number, y: number): Promise<void> {
    const session = this.getSessionOrThrow(id);
    try {
      await session.page.mouse.click(x, y);
      session.meta.url = session.page.url();
      session.meta.lastActivityAt = Date.now();
    } catch (err) {
      throw new Error(`Tap failed: ${(err as Error).message}`);
    }
  }

  async scroll(id: string, x: number, y: number, deltaX: number, deltaY: number): Promise<void> {
    const session = this.getSessionOrThrow(id);
    try {
      await session.page.mouse.wheel(deltaX, deltaY);
      session.meta.lastActivityAt = Date.now();
    } catch (err) {
      throw new Error(`Scroll failed: ${(err as Error).message}`);
    }
  }

  async typeText(id: string, text: string): Promise<void> {
    const session = this.getSessionOrThrow(id);
    try {
      await session.page.keyboard.type(text);
      session.meta.lastActivityAt = Date.now();
    } catch (err) {
      throw new Error(`Text input failed: ${(err as Error).message}`);
    }
  }

  async getState(id: string): Promise<SessionState> {
    const session = this.getSessionOrThrow(id);
    let title: string | null = null;
    try {
      title = await session.page.title();
    } catch {
      // title is optional
    }
    return {
      id: session.meta.id,
      url: session.page.url() || null,
      title,
      createdAt: session.meta.createdAt,
      lastActivityAt: session.meta.lastActivityAt,
      viewportWidth: session.meta.viewportWidth,
      viewportHeight: session.meta.viewportHeight,
    };
  }

  async deleteSession(id: string): Promise<void> {
    const session = this.sessions.get(id);
    if (!session) return;
    try {
      await session.context.close();
    } catch {
      // best-effort cleanup
    }
    this.sessions.delete(id);
  }

  validateToken(id: string, token: string): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    return session.meta.token === token;
  }

  hasSession(id: string): boolean {
    return this.sessions.has(id);
  }

  async close(): Promise<void> {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }
    for (const [id] of this.sessions) {
      await this.deleteSession(id);
    }
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
    }
  }

  private getSessionOrThrow(id: string): InternalSession {
    const session = this.sessions.get(id);
    if (!session) {
      const err = new Error('Session not found') as Error & { code?: string };
      err.code = 'SESSION_NOT_FOUND';
      throw err;
    }
    return session;
  }

  private cleanupIdleSessions(): void {
    const now = Date.now();
    for (const [id, session] of this.sessions) {
      if (now - session.meta.lastActivityAt > SESSION_IDLE_TIMEOUT_MS) {
        this.deleteSession(id).catch(() => {});
      }
    }
  }
}
