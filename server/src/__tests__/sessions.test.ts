// Unit tests for the sessions API routes.
// These tests mock the SessionManager so no real browser is launched.

import express, { Application } from 'express';
import request from 'supertest';
import { createSessionsRouter } from '../routes/sessions';
import { SessionManager } from '../sessionManager';
import { SessionState } from '../types';

jest.mock('../sessionManager');

const MockedSessionManager = SessionManager as jest.MockedClass<typeof SessionManager>;

function buildApp(manager: SessionManager): Application {
  const app = express();
  app.use(express.json());
  app.use('/sessions', createSessionsRouter(manager));
  return app;
}

describe('POST /sessions', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    app = buildApp(manager);
  });

  it('creates a session with defaults and returns 201', async () => {
    manager.createSession.mockResolvedValue({
      id: 'sess-1',
      token: 'tok-1',
      viewportWidth: 320,
      viewportHeight: 568,
    });

    const res = await request(app).post('/sessions').send({});
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      sessionId: 'sess-1',
      token: 'tok-1',
      viewportWidth: 320,
      viewportHeight: 568,
    });
    expect(manager.createSession).toHaveBeenCalledWith(320, 568, undefined);
  });

  it('passes custom viewport and url to manager', async () => {
    manager.createSession.mockResolvedValue({
      id: 'sess-2',
      token: 'tok-2',
      viewportWidth: 375,
      viewportHeight: 667,
    });

    const res = await request(app)
      .post('/sessions')
      .send({ viewportWidth: 375, viewportHeight: 667, url: 'https://example.com' });
    expect(res.status).toBe(201);
    expect(manager.createSession).toHaveBeenCalledWith(375, 667, 'https://example.com');
  });

  it('returns 500 if manager throws', async () => {
    manager.createSession.mockRejectedValue(new Error('Browser init failed'));
    const res = await request(app).post('/sessions').send({});
    expect(res.status).toBe(500);
    expect(res.body.code).toBe('SESSION_CREATE_FAILED');
  });
});

describe('POST /sessions/:id/navigate', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('navigates and returns ok', async () => {
    manager.navigate.mockResolvedValue();
    const res = await request(app)
      .post('/sessions/sess-1/navigate')
      .set('Authorization', 'Bearer tok-1')
      .send({ url: 'https://example.com' });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  it('returns 400 if url missing', async () => {
    const res = await request(app)
      .post('/sessions/sess-1/navigate')
      .set('Authorization', 'Bearer tok-1')
      .send({});
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INVALID_PAYLOAD');
  });

  it('returns 401 if token missing', async () => {
    const res = await request(app)
      .post('/sessions/sess-1/navigate')
      .send({ url: 'https://example.com' });
    expect(res.status).toBe(401);
  });

  it('returns 404 if session not found', async () => {
    manager.hasSession.mockReturnValue(false);
    const res = await request(app)
      .post('/sessions/bad-id/navigate')
      .set('Authorization', 'Bearer tok-1')
      .send({ url: 'https://example.com' });
    expect(res.status).toBe(404);
  });

  it('returns 502 if navigation fails', async () => {
    manager.navigate.mockRejectedValue(new Error('timeout'));
    const res = await request(app)
      .post('/sessions/sess-1/navigate')
      .set('Authorization', 'Bearer tok-1')
      .send({ url: 'https://example.com' });
    expect(res.status).toBe(502);
    expect(res.body.code).toBe('NAVIGATION_FAILED');
  });
});

describe('GET /sessions/:id/frame', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('returns JPEG frame', async () => {
    const fakeJpeg = Buffer.from([0xff, 0xd8, 0xff]);
    manager.getFrame.mockResolvedValue(fakeJpeg);

    const res = await request(app)
      .get('/sessions/sess-1/frame')
      .set('Authorization', 'Bearer tok-1');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/image\/jpeg/);
    expect(res.body).toBeDefined();
  });
});

describe('POST /sessions/:id/input/tap', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('sends tap and returns ok', async () => {
    manager.tap.mockResolvedValue();
    const res = await request(app)
      .post('/sessions/sess-1/input/tap')
      .set('Authorization', 'Bearer tok-1')
      .send({ x: 100, y: 200 });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(manager.tap).toHaveBeenCalledWith('sess-1', 100, 200);
  });

  it('returns 400 if x or y missing', async () => {
    const res = await request(app)
      .post('/sessions/sess-1/input/tap')
      .set('Authorization', 'Bearer tok-1')
      .send({ x: 100 });
    expect(res.status).toBe(400);
  });
});

describe('POST /sessions/:id/input/scroll', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('sends scroll and returns ok', async () => {
    manager.scroll.mockResolvedValue();
    const res = await request(app)
      .post('/sessions/sess-1/input/scroll')
      .set('Authorization', 'Bearer tok-1')
      .send({ x: 0, y: 0, deltaX: 0, deltaY: 100 });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(manager.scroll).toHaveBeenCalledWith('sess-1', 0, 0, 0, 100);
  });

  it('returns 400 if any field missing', async () => {
    const res = await request(app)
      .post('/sessions/sess-1/input/scroll')
      .set('Authorization', 'Bearer tok-1')
      .send({ x: 0, y: 0, deltaX: 0 });
    expect(res.status).toBe(400);
  });
});

describe('POST /sessions/:id/input/text', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('sends text and returns ok', async () => {
    manager.typeText.mockResolvedValue();
    const res = await request(app)
      .post('/sessions/sess-1/input/text')
      .set('Authorization', 'Bearer tok-1')
      .send({ text: 'hello world' });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(manager.typeText).toHaveBeenCalledWith('sess-1', 'hello world');
  });

  it('returns 400 if text missing', async () => {
    const res = await request(app)
      .post('/sessions/sess-1/input/text')
      .set('Authorization', 'Bearer tok-1')
      .send({});
    expect(res.status).toBe(400);
  });
});

describe('GET /sessions/:id/state', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('returns session state', async () => {
    const state: SessionState = {
      id: 'sess-1',
      url: 'https://example.com',
      title: 'Example',
      createdAt: 1000,
      lastActivityAt: 2000,
      viewportWidth: 320,
      viewportHeight: 568,
    };
    manager.getState.mockResolvedValue(state);
    const res = await request(app)
      .get('/sessions/sess-1/state')
      .set('Authorization', 'Bearer tok-1');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject(state);
  });
});

describe('DELETE /sessions/:id', () => {
  let manager: jest.Mocked<SessionManager>;
  let app: Application;

  beforeEach(() => {
    manager = new MockedSessionManager() as jest.Mocked<SessionManager>;
    manager.hasSession.mockReturnValue(true);
    manager.validateToken.mockReturnValue(true);
    app = buildApp(manager);
  });

  it('deletes session and returns ok', async () => {
    manager.deleteSession.mockResolvedValue();
    const res = await request(app)
      .delete('/sessions/sess-1')
      .set('Authorization', 'Bearer tok-1');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });
});
