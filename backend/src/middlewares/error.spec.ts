import { Request, Response } from 'express';
import { ZodError, z } from 'zod';
import { errorHandler } from './error';
import { ApiError } from '../utils/apiError';

function mockRes() {
  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  } as unknown as Response;
  return res;
}

describe('errorHandler (regression: BUG-004)', () => {
  it('returns 400 for a body-parser SyntaxError from malformed JSON, not 500', () => {
    const res = mockRes();
    const err = Object.assign(new SyntaxError('Unexpected token in JSON'), { body: '{bad json' });

    errorHandler(err, {} as Request, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: 'Malformed JSON body' })
    );
  });

  it('still returns 500 for a plain SyntaxError with no body property (not a body-parser error)', () => {
    const res = mockRes();
    const err = new SyntaxError('some unrelated syntax error');

    errorHandler(err, {} as Request, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
  });

  it('returns 400 with field detail for a ZodError', () => {
    const res = mockRes();
    let zodErr: ZodError;
    try {
      z.object({ amount: z.number() }).parse({ amount: 'not-a-number' });
      throw new Error('expected parse to throw');
    } catch (e) {
      zodErr = e as ZodError;
    }

    errorHandler(zodErr, {} as Request, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('amount') })
    );
  });

  it('respects the status code on a thrown ApiError', () => {
    const res = mockRes();
    const err = new ApiError(403, 'Not your offer');

    errorHandler(err, {} as Request, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: 'Not your offer' })
    );
  });

  it('falls back to 500 for a genuinely unexpected error', () => {
    const res = mockRes();
    const err = new Error('database connection lost');

    errorHandler(err, {} as Request, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(500);
  });
});