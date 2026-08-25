import axios from 'axios';

export interface InstagramStats {
  views: number;
  likes: number;
  shares: number;
  comments: number;
  title: string;
  author: string;
}

const RAPIDAPI_KEY  = process.env.RAPIDAPI_KEY ?? '';
const RAPIDAPI_HOST = process.env.RAPIDAPI_INSTAGRAM_HOST ?? '';
const SHORTCODE_RE = /\/(?:reel|p|tv)\/([A-Za-z0-9_-]+)/;

function isInstagramHost(url: string): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return host === 'instagram.com' || host.endsWith('.instagram.com') || host === 'instagr.am';
  } catch {
    return false;
  }
}

async function followRedirects(startUrl: string, maxHops = 5): Promise<string> {
  let current = startUrl;
  for (let hop = 0; hop < maxHops; hop++) {
    if (SHORTCODE_RE.test(current)) return current;
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

async function resolveShortcode(rawUrl: string): Promise<string> {
  if (!isInstagramHost(rawUrl)) {
    throw new Error('Please paste an Instagram Reel link (instagram.com)');
  }
  const resolved = SHORTCODE_RE.test(rawUrl) ? rawUrl : await followRedirects(rawUrl);
  const match = resolved.match(SHORTCODE_RE);
  if (!match?.[1]) {
    throw new Error(
      'Could not read this Reel — please open it in Instagram, tap Share, ' +
      'then "Copy Link" again and try submitting once more.'
    );
  }
  return match[1];
}

const REQUEST_PATH = '/v1/media_info_by_shortcode';
const REQUEST_PARAM_NAME = 'shortcode';

export async function fetchInstagramStats(videoUrl: string): Promise<InstagramStats> {
  if (!RAPIDAPI_HOST) {
    throw new Error(
      'Instagram stat tracking isn\'t configured yet — set RAPIDAPI_INSTAGRAM_HOST in the backend .env ' +
      '(see the comment above fetchInstagramStats for what to subscribe to).'
    );
  }

  const trimmedUrl = videoUrl.trim();
  const shortcode = await resolveShortcode(trimmedUrl);

  const result: InstagramStats = { views: 0, likes: 0, shares: 0, comments: 0, title: '', author: '' };

  const res = await axios.get(`https://${RAPIDAPI_HOST}${REQUEST_PATH}`, {
    params: { [REQUEST_PARAM_NAME]: shortcode },
    headers: {
      'x-rapidapi-key':  RAPIDAPI_KEY,
      'x-rapidapi-host': RAPIDAPI_HOST,
      'Content-Type':    'application/json',
    },
    timeout: 12000,
  });

  const data = res.data;
  const media =
    data?.data?.items?.[0] ??
    data?.items?.[0] ??
    data?.data ??
    data?.media ??
    data?.item ??
    data ??
    null;
  if (!media) {
    throw new Error('Unexpected response from Instagram API');
  }

  result.views    = Number(media.play_count ?? media.ig_play_count ?? media.view_count ?? 0);
  result.likes    = Number(media.like_count ?? 0);
  result.comments = Number(media.comment_count ?? 0);
  result.shares   = Number(media.reshare_count ?? 0);
  result.title    = (media.caption?.text ?? media.caption ?? media.title ?? '').toString().slice(0, 200);
  result.author   = media.user?.username ?? media.owner?.username ?? media.username ?? '';

  return result;
}