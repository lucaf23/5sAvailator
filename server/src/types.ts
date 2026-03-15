// Shared types for the 5sAvailator server API

export interface Session {
  id: string;
  token: string;
  url: string | null;
  createdAt: number;
  lastActivityAt: number;
  viewportWidth: number;
  viewportHeight: number;
}

export interface SessionState {
  id: string;
  url: string | null;
  title: string | null;
  createdAt: number;
  lastActivityAt: number;
  viewportWidth: number;
  viewportHeight: number;
}

export interface CreateSessionRequest {
  url?: string;
  viewportWidth?: number;
  viewportHeight?: number;
}

export interface CreateSessionResponse {
  sessionId: string;
  token: string;
  viewportWidth: number;
  viewportHeight: number;
}

export interface NavigateRequest {
  url: string;
}

export interface TapRequest {
  x: number;
  y: number;
}

export interface ScrollRequest {
  x: number;
  y: number;
  deltaX: number;
  deltaY: number;
}

export interface TextInputRequest {
  text: string;
}

export interface ErrorResponse {
  error: string;
  code: string;
}
