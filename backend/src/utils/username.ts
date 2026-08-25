import { pool, DbRow } from '../config/db';

function sanitize(base: string): string {
  const cleaned = base.toLowerCase().replace(/[^a-z0-9_]/g, '');
  if (cleaned.length >= 2) return cleaned.slice(0, 76); // leave room for a numeric suffix
  return 'user';
}

export async function generateUniqueUsername(base: string): Promise<string> {
  const root = sanitize(base);
  const [rows] = await pool.query<DbRow[]>(
    `SELECT username FROM influencer_profiles WHERE username = ? OR username LIKE ?`,
    [root, `${root}%`]
  );
  const taken = new Set(rows.map((r) => (r as { username: string }).username));
  if (!taken.has(root)) return root;
  let n = 2;
  while (taken.has(`${root}${n}`)) n++;
  return `${root}${n}`;
}