import { generateUniqueUsername } from './username';
import { pool } from '../config/db';

jest.mock('../config/db', () => ({
  pool: { query: jest.fn() },
}));

function mockExistingUsernames(usernames: string[]) {
  (pool.query as jest.Mock).mockResolvedValue([usernames.map((username) => ({ username }))]);
}

describe('generateUniqueUsername', () => {
  it('lowercases and strips characters outside [a-z0-9_]', async () => {
    mockExistingUsernames([]);
    const result = await generateUniqueUsername('Ava R!chie 99');
    expect(result).toBe('avarchie99');
  });

  it('returns the sanitized base directly when it is not taken', async () => {
    mockExistingUsernames(['someone_else']);
    const result = await generateUniqueUsername('ava');
    expect(result).toBe('ava');
  });

  it('appends the next free numeric suffix when the base is taken', async () => {
    mockExistingUsernames(['ava', 'ava2', 'ava3']);
    const result = await generateUniqueUsername('ava');
    expect(result).toBe('ava4');
  });

  it('falls back to "user" when the sanitized base is under 2 characters', async () => {
    mockExistingUsernames([]);
    const result = await generateUniqueUsername('!!');
    expect(result).toBe('user');
  });

  it('truncates very long input to leave room for a numeric suffix', async () => {
    mockExistingUsernames([]);
    const longName = 'a'.repeat(200);
    const result = await generateUniqueUsername(longName);
    expect(result.length).toBeLessThanOrEqual(76);
  });
});