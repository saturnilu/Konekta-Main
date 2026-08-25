import { pool, DbRow } from '../config/db';
import { fetchTikTokStats } from './tiktok.service';
import { fetchInstagramStats } from './instagram.service';

export interface VideoStats {
  platform: VideoPlatform;
  views: number;
  likes: number;
  shares: number;
  comments: number;
  title: string;
  author: string;
}

export type VideoPlatform = 'tiktok' | 'instagram';

export function detectPlatform(url: string): VideoPlatform | null {
  try {
    const host = new URL(url).hostname.toLowerCase();
    if (host === 'tiktok.com' || host.endsWith('.tiktok.com')) return 'tiktok';
    if (host === 'instagram.com' || host.endsWith('.instagram.com') || host === 'instagr.am') return 'instagram';
    return null;
  } catch {
    return null;
  }
}

export async function fetchVideoStats(url: string): Promise<VideoStats> {
  const platform = detectPlatform(url);
  if (!platform) {
    throw new Error('Please paste a TikTok or Instagram Reel link');
  }
  if (platform === 'tiktok') {
    const stats = await fetchTikTokStats(url);
    return { ...stats, platform: 'tiktok' };
  }
  const stats = await fetchInstagramStats(url);
  return { ...stats, platform: 'instagram' };
}

export async function fetchVideoStatsForPlatform(url: string, platform: VideoPlatform): Promise<VideoStats> {
  if (platform === 'tiktok') {
    const stats = await fetchTikTokStats(url);
    return { ...stats, platform: 'tiktok' };
  }
  const stats = await fetchInstagramStats(url);
  return { ...stats, platform: 'instagram' };
}

export async function upsertDailyStats(influencerUserId: number): Promise<void> {
  const [rows] = await pool.query<DbRow[]>(
    `SELECT
       COALESCE(SUM(views_count),    0) AS v,
       COALESCE(SUM(likes_count),    0) AS l,
       COALESCE(SUM(shares_count),   0) AS s,
       COALESCE(SUM(comments_count), 0) AS c
     FROM submitted_videos
    WHERE influencer_user_id = ?`,
    [influencerUserId]
  );
  const { v, l, s, c } = rows[0] as { v: number; l: number; s: number; c: number };

  await pool.query(
    `INSERT INTO video_daily_stats
       (influencer_user_id, stat_date, views_count, likes_count, shares_count, comments_count)
     VALUES (?, CURDATE(), ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       views_count    = VALUES(views_count),
       likes_count    = VALUES(likes_count),
       shares_count   = VALUES(shares_count),
       comments_count = VALUES(comments_count),
       updated_at     = NOW()`,
    [influencerUserId, v, l, s, c]
  );
}

export async function refreshAllVideosForUser(userId: number): Promise<void> {
  const [videos] = await pool.query<DbRow[]>(
    `SELECT id, offer_id, influencer_user_id, video_url, platform
       FROM submitted_videos
      WHERE influencer_user_id = ?`,
    [userId]
  );

  if (!videos.length) return;

  for (const row of videos) {
    const v = row as {
      id: number; offer_id: number; influencer_user_id: number;
      video_url: string; platform: VideoPlatform;
    };
    try {
      const stats = await fetchVideoStatsForPlatform(v.video_url, v.platform ?? 'tiktok');

      await pool.query(
        `UPDATE submitted_videos
            SET views_count = ?, likes_count = ?, shares_count = ?, comments_count = ?, fetched_at = NOW()
          WHERE id = ?`,
        [stats.views, stats.likes, stats.shares, stats.comments, v.id]
      );

      const [aggRows] = await pool.query<DbRow[]>(
        `SELECT COALESCE(SUM(views_count), 0) AS total_views,
                COALESCE(SUM(likes_count), 0)  AS total_likes,
                COALESCE(SUM(shares_count), 0) AS total_shares
           FROM submitted_videos
          WHERE offer_id = ? AND influencer_user_id = ?`,
        [v.offer_id, v.influencer_user_id]
      );
      const agg = aggRows[0] as { total_views: number; total_likes: number; total_shares: number };

      const [offerRows] = await pool.query<DbRow[]>(
        'SELECT target_views, target_likes FROM offers WHERE id = ?',
        [v.offer_id]
      );
      if (!offerRows.length) continue;
      const offer = offerRows[0] as { target_views: number; target_likes: number };

      const vPct = offer.target_views > 0 ? Math.min(agg.total_views / offer.target_views, 1) : 1;
      const lPct = offer.target_likes > 0 ? Math.min(agg.total_likes / offer.target_likes, 1) : 1;
      const noTarget = offer.target_views === 0 && offer.target_likes === 0;
      const progress = noTarget ? 100 : Math.round((vPct * 0.6 + lPct * 0.4) * 100);

      await pool.query(
        `UPDATE campaign_applicants
            SET views = ?, likes = ?, shares = ?, progress = ?
          WHERE offer_id = ? AND influencer_user_id = ?`,
        [agg.total_views, agg.total_likes, agg.total_shares, progress, v.offer_id, v.influencer_user_id]
      );
    } catch {
      continue;
    }
  }

  try {
    await upsertDailyStats(userId);
  } catch {
  }
}