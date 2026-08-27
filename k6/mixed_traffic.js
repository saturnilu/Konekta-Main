import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const authFailRate = new Rate('auth_failures');
const browseLatency = new Trend('browse_latency', true);
const authLatency = new Trend('auth_latency', true);
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

const INFLUENCER_ACCOUNTS = [
  { email: 'ava@konekta-mobile.test', password: 'password123' },
  { email: 'leo@konekta-mobile.test', password: 'password123' },
];
const BRAND_ACCOUNTS = [
  { email: 'brand1@konekta-mobile.test', password: 'password123' },
  { email: 'brand2@konekta-mobile.test', password: 'password123' },
];
const OFFER_IDS_FALLBACK = [1, 2, 3, 4, 5];

function randomFrom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export function setup() {
  const res = http.get(`${BASE_URL}/offers?limit=50`);
  if (res.status !== 200) {
    console.warn(`setup: could not fetch offers (status ${res.status}), falling back to a hardcoded ID list`);
    return { offerIds: OFFER_IDS_FALLBACK };
  }
  const body = JSON.parse(res.body);
  const ids = (body.data || []).map((o) => o.id).filter((id) => Number.isFinite(id));
  if (ids.length === 0) {
    console.warn('setup: /offers returned no usable ids, falling back to a hardcoded ID list');
    return { offerIds: OFFER_IDS_FALLBACK };
  }
  return { offerIds: ids };
}

export const options = {
  scenarios: {
    browsing: {
      executor: 'ramping-vus',
      exec: 'browseFlow',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 30 },
        { duration: '40s', target: 30 },
        { duration: '10s', target: 0 },
      ],
    },
    influencer_login_and_apply: {
      executor: 'ramping-vus',
      exec: 'influencerFlow',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 4 },
        { duration: '40s', target: 4 },
        { duration: '10s', target: 0 },
      ],
    },
    brand_dashboard: {
      executor: 'ramping-vus',
      exec: 'brandFlow',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 2 },
        { duration: '40s', target: 2 },
        { duration: '10s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.05'],
    browse_latency: ['p(95)<500'],
    auth_failures: ['rate<0.5'], 
  },
};

export function browseFlow(data) {
  group('browse offers list', () => {
    const res = http.get(`${BASE_URL}/offers`);
    browseLatency.add(res.timings.duration);
    check(res, { 'offers list 200': (r) => r.status === 200 });
  });

  sleep(Math.random() * 1.5);

  group('browse offer detail', () => {
    const id = randomFrom(data.offerIds);
    const res = http.get(`${BASE_URL}/offers/${id}`);
    browseLatency.add(res.timings.duration);
    check(res, { 'offer detail 200': (r) => r.status === 200 });
  });

  sleep(Math.random() * 1.5);

  group('browse discovery', () => {
    const res = http.get(`${BASE_URL}/influencers`);
    browseLatency.add(res.timings.duration);
    check(res, { 'influencers list 200': (r) => r.status === 200 });
  });

  sleep(Math.random() * 2);
}

export function influencerFlow(data) {
  const account = randomFrom(INFLUENCER_ACCOUNTS);
  let token;

  group('influencer login', () => {
    const res = http.post(
      `${BASE_URL}/auth/login`,
      JSON.stringify({ email: account.email, password: account.password }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    authLatency.add(res.timings.duration);
    const ok = res.status === 200;
    authFailRate.add(!ok);
    if (ok) {
      token = JSON.parse(res.body).data.token;
    }
  });

  if (!token) {
    sleep(1);
    return;
  }

  const authHeaders = { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } };

  sleep(Math.random());

  group('view own profile', () => {
    const res = http.get(`${BASE_URL}/profile/me`, authHeaders);
    check(res, { 'profile 200': (r) => r.status === 200 });
  });

  sleep(Math.random());

  group('apply to a random open offer', () => {
    const id = randomFrom(data.offerIds);
    const res = http.post(
      `${BASE_URL}/offers/${id}/apply`,
      JSON.stringify({ message: 'Interested in this campaign (k6 load test)' }),
      authHeaders
    );

    check(res, { 'apply handled correctly': (r) => r.status === 201 || r.status === 409 });
  });

  sleep(Math.random() * 2);
}

export function brandFlow() {
  const account = randomFrom(BRAND_ACCOUNTS);
  let token;

  group('brand login', () => {
    const res = http.post(
      `${BASE_URL}/auth/login`,
      JSON.stringify({ email: account.email, password: account.password }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    authLatency.add(res.timings.duration);
    const ok = res.status === 200;
    authFailRate.add(!ok);
    if (ok) {
      token = JSON.parse(res.body).data.token;
    }
  });

  if (!token) {
    sleep(1);
    return;
  }

  const authHeaders = { headers: { Authorization: `Bearer ${token}` } };

  sleep(Math.random());

  group('brand dashboard overview', () => {
    const res = http.get(`${BASE_URL}/dashboard/overview`, authHeaders);
    check(res, { 'dashboard 200': (r) => r.status === 200 });
  });

  sleep(Math.random());

  group('brand lists own offers', () => {
    const res = http.get(`${BASE_URL}/offers/mine`, authHeaders);
    check(res, { 'offers/mine 200': (r) => r.status === 200 });
  });

  sleep(Math.random() * 2);
}