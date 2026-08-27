import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { requireAuth, requireRole, signToken, AuthPayload } from '../core/middlewares/auth';
import { env } from '../config/env';
import { ApiError } from '../core/utils/apiError';

function mockReq(headers: Record<string, string> = {}): Request {
  return { headers, user: undefined } as unknown as Request;
}

const samplePayload: AuthPayload = { id: 1, role: 'influencer', email: 'a@test.com', name: 'A' };

describe('requireAuth', () => {
  it('calls next with a 401 ApiError when there is no Authorization header', () => {
    const req = mockReq();
    const next = jest.fn();

    requireAuth(req, {} as Response, next);

    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(401);
    expect(req.user).toBeUndefined();
  });

  it('calls next with a 401 ApiError when the header does not start with "Bearer "', () => {
    const req = mockReq({ authorization: 'Basic sometoken' });
    const next = jest.fn();

    requireAuth(req, {} as Response, next);

    const err = next.mock.calls[0][0];
    expect(err.status).toBe(401);
  });

  it('calls next with a 401 ApiError for a token signed with the wrong secret', () => {
    const forged = jwt.sign(samplePayload, 'wrong-secret');
    const req = mockReq({ authorization: `Bearer ${forged}` });
    const next = jest.fn();

    requireAuth(req, {} as Response, next);

    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(401);
    expect(req.user).toBeUndefined();
  });

  it('sets req.user and calls next() with no error for a valid token', () => {
    const token = signToken(samplePayload);
    const req = mockReq({ authorization: `Bearer ${token}` });
    const next = jest.fn();

    requireAuth(req, {} as Response, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.user).toMatchObject({ id: 1, role: 'influencer' });
  });

  it('rejects an expired token', () => {
    const expired = jwt.sign(samplePayload, env.jwtSecret, { expiresIn: -10 });
    const req = mockReq({ authorization: `Bearer ${expired}` });
    const next = jest.fn();

    requireAuth(req, {} as Response, next);

    const err = next.mock.calls[0][0];
    expect(err.status).toBe(401);
  });
});

describe('requireRole', () => {
  it('calls next with a 401 ApiError when there is no authenticated user', () => {
    const req = mockReq();
    const next = jest.fn();

    requireRole('brand')(req, {} as Response, next);

    expect(next.mock.calls[0][0].status).toBe(401);
  });

  it('calls next with a 403 ApiError when the user has the wrong role', () => {
    const req = mockReq();
    req.user = samplePayload; 
    const next = jest.fn();

    requireRole('brand')(req, {} as Response, next);

    expect(next.mock.calls[0][0].status).toBe(403);
  });

  it('calls next() with no error when the role matches', () => {
    const req = mockReq();
    req.user = samplePayload; 
    const next = jest.fn();

    requireRole('influencer')(req, {} as Response, next);

    expect(next).toHaveBeenCalledWith();
  });
});