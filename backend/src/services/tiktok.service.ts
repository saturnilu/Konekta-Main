import axios from 'axios';

export interface TikTokStats {
  views: number;
  likes: number;
  shares: number;
  comments: number;
  title: string;
  author: string;
}

const RAPIDAPI_KEY  = process.env.RAPIDAPI_KEY ?? '';
const RAPIDAPI_HOST = process.env.RAPIDAPI_TIKTOK_HOST ?? 'tiktok-api23.p.rapidapi.com';

const VIDEO_ID_RE = /\/video\/(\d+)/;

function isTikTokHost(url: string): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return host === 'tiktok.com' || host.endsWith('.tiktok.com');
  } catch {
    return false;
  }
}

export async function followRedirects(startUrl: string, maxHops = 5): Promise<string> {
  let current = startUrl;
  for (let hop = 0; hop < maxHops; hop++) {
    if (VIDEO_ID_RE.test(current)) return current;
    let location: string | undefined;
    try {
      const res = await axios.get(current, {
        maxRedirects: 0,
        validateStatus: (s) => (s >= 200 && s < 400),
        timeout: 8000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
        },
      });
      location = res.headers['location'];
    } catch (err: any) {
      location = err?.response?.headers?.['location'];
      if (!location) throw err;
    }
    if (!location) return current; 
    current = location.startsWith('http') ? location : new URL(location, current).toString();
  }
  return current;
}

async function resolveVideoId(rawUrl: string): Promise<string> {
  if (!isTikTokHost(rawUrl)) {
    throw new Error('Please paste a TikTok link (tiktok.com)');
  }
  const resolved = VIDEO_ID_RE.test(rawUrl) ? rawUrl : await followRedirects(rawUrl);
  const match = resolved.match(VIDEO_ID_RE);
  if (!match?.[1]) {
    throw new Error(
      'Could not read the video ID from this link. Please open the video in TikTok, ' +
      'tap Share, then "Copy Link" again and try submitting once more.'
    );
  }
  return match[1];
}

export async function fetchTikTokStats(videoUrl: string): Promise<TikTokStats> {
  const trimmedUrl = videoUrl.trim();
  const videoId = await resolveVideoId(trimmedUrl);

  const result: TikTokStats = {
    views: 0, likes: 0, shares: 0, comments: 0, title: '', author: '',
  };

  const res = await axios.get(`https://${RAPIDAPI_HOST}/api/post/detail`, {
    params: { videoId },
    headers: {
      'x-rapidapi-key':  RAPIDAPI_KEY,
      'x-rapidapi-host': RAPIDAPI_HOST,
      'Content-Type':    'application/json',
    },
    timeout: 12000,
  });

  const data = res.data;

  const itemStruct =
    data?.itemInfo?.itemStruct ??
    data?.data?.itemInfo?.itemStruct ??
    data?.data ??
    data?.item ??
    null;

  if (!itemStruct) {
    throw new Error('Unexpected response from TikTok API');
  }

  const stats   = itemStruct.stats   ?? itemStruct.statsV2 ?? {};
  const statics = itemStruct.statistics ?? {};

  result.views    = Number(stats.playCount    ?? stats.play_count    ?? statics.play_count    ?? 0);
  result.likes    = Number(stats.diggCount    ?? stats.digg_count    ?? statics.digg_count    ?? 0);
  result.shares   = Number(stats.shareCount   ?? stats.share_count   ?? statics.share_count   ?? 0);
  result.comments = Number(stats.commentCount ?? stats.comment_count ?? statics.comment_count ?? 0);
  result.title    = (itemStruct.desc ?? itemStruct.title ?? itemStruct.contents?.[0]?.desc ?? '').slice(0, 200);
  result.author   = itemStruct.author?.nickname ?? itemStruct.author?.unique_id ?? itemStruct.author?.uniqueId ?? '';

  return result;
}