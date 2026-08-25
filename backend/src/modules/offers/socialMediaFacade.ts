import { pool, DbRow } from '../../config/db';
import {
  ISocialMediaAdapter,
  PlatformReport,
  PostContent,
  SocialMediaMetrics,
  TikTokAdapter,
  InstagramAdapter,
  YouTubeAdapter,
} from './socialMediaAdapters';
import { eventBus } from './eventBus';

interface CampaignSummary {
  offerId: number;
  platforms: PlatformReport[];
  combined: {
    totalViews: number;
    totalLikes: number;
    totalShares: number;
    platformCount: number;
  };
  syncedAt: Date;
}

interface PublishResult {
  platform: string;
  post: PostContent;
}

export class SocialMediaFacade {
  private adapters: Map<string, ISocialMediaAdapter>;

  constructor() {
    this.adapters = new Map<string, ISocialMediaAdapter>();
    this.adapters.set('tiktok', new TikTokAdapter());
    this.adapters.set('instagram', new InstagramAdapter());
    this.adapters.set('youtube', new YouTubeAdapter());
  }

  private getAdapter(platform: string): ISocialMediaAdapter {
    const adapter = this.adapters.get(platform.toLowerCase());
    if (!adapter) {
      throw new Error(`Unsupported platform: ${platform}`);
    }
    return adapter;
  }

  async getCampaignSummary(offerId: number): Promise<CampaignSummary> {
    const [accountRows] = await pool.query<DbRow[]>(
      `SELECT DISTINCT platform FROM social_media_accounts
       WHERE influencer_user_id = (
         SELECT influencer_user_id FROM offers WHERE id = ?
       )`,
      [offerId]
    );

    const platforms = (accountRows as { platform: string }[]).map((r) => r.platform);
    const platformList = platforms.length ? platforms : ['tiktok', 'instagram', 'youtube'];

    const reports = await Promise.all(
      platformList.map(async (p) => {
        try {
          return await this.getAdapter(p).fetchCampaignReport(offerId);
        } catch (e) {
          console.warn(`[SocialMediaFacade] failed to fetch report from ${p}:`, e);
          return null;
        }
      })
    );

    const validReports = reports.filter((r): r is PlatformReport => r !== null);

    return {
      offerId,
      platforms: validReports,
      combined: {
        totalViews: validReports.reduce((s, r) => s + r.totalViews, 0),
        totalLikes: validReports.reduce((s, r) => s + r.totalLikes, 0),
        totalShares: validReports.reduce((s, r) => s + r.totalShares, 0),
        platformCount: validReports.length,
      },
      syncedAt: new Date(),
    };
  }

  async syncMetrics(offerId: number): Promise<CampaignSummary> {
    const summary = await this.getCampaignSummary(offerId);

    for (const report of summary.platforms) {
      for (const post of report.posts) {
        await pool.query(
          `UPDATE campaign_applicants
           SET views = ?, likes = ?, shares = ?, updated_at = NOW()
           WHERE id = ?`,
          [post.views, post.likes, post.shares, Number(post.postId)]
        ).catch((err) => {
          console.warn(`[SocialMediaFacade] failed to persist metrics for post ${post.postId}:`, err);
        });
      }
    }

    await eventBus.publish('metrics.synced', {
      offer_id: offerId,
      total_views: summary.combined.totalViews,
      total_likes: summary.combined.totalLikes,
      total_shares: summary.combined.totalShares,
      platform_count: summary.combined.platformCount,
    });

    return summary;
  }

  async publishPost(platform: string, _userId: number, content: PostContent): Promise<PublishResult> {
    const adapter = this.getAdapter(platform);
    const post = await adapter.publish(content);
    return { platform, post };
  }

  async getMetrics(platform: string, postId: string): Promise<SocialMediaMetrics> {
    return this.getAdapter(platform).getMetrics(postId);
  }
}

export const socialMediaFacade = new SocialMediaFacade();
export default socialMediaFacade;
