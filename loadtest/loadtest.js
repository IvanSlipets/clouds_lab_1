import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';

const cacheHitRate = new Rate('sports_cache_hit_rate');
const sportsDbReads = new Counter('sports_list_db_reads');


const BASE_URL = (__ENV.API_URL || '').replace(/\/+$/, '');
const USERS = Number(__ENV.TEST_USERS || 20);
const SMOKE = __ENV.SMOKE === '1';

export const options = {
  stages: SMOKE
    ? [
        { duration: '5s', target: 1 },
        { duration: '20s', target: 1 },
        { duration: '5s', target: 0 },
      ]
    : [
        { duration: '3m', target: USERS },
        { duration: '5m', target: USERS },
        { duration: '2m', target: 0 },
      ],

  summaryTrendStats: [
    'avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'
  ],

  thresholds: {
    http_req_failed: ['rate<0.05'],
    checks: ['rate>0.95'],
  },
};

export function setup() {
  if (!BASE_URL || !__ENV.API_PASSWORD) {
    throw new Error('API_URL or API_PASSWORD is missing');
  }

  const response = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({
      username: __ENV.API_USER || 'admin',
      password: __ENV.API_PASSWORD,
    }),
    {
      headers: { 'Content-Type': 'application/json' },
      timeout: '15s',
    }
  );

  if (response.status !== 200) {
    throw new Error(`Login failed: HTTP ${response.status}`);
  }

  const token = response.json('access_token');

  if (!token) {
    throw new Error('JWT token was not returned');
  }

  return { token };
}

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${data.token}`,
  };

  const name = `k6-${Date.now()}-${__VU}-${__ITER}`;

  const created = http.post(
    `${BASE_URL}/api/sports/`,
    JSON.stringify({
      name: name,
      description: 'Created by k6 load test',
    }),
    {
      headers,
      tags: { name: 'POST /api/sports/' },
    }
  );

  const createdOK = check(created, {
    'sport created (201)': (r) => r.status === 201,
  });

  if (!createdOK) {
    sleep(1);
    return;
  }

  const id = created.json('sport_id');

  if (!Number.isInteger(id)) {
    throw new Error('Created sport has no valid ID');
  }

  const reads = [
    ['/api/sports/', 'sports-list'],
    [`/api/sports/${id}`, 'sport-detail'],
    ['/api/sports/', 'sports-list'],
    [`/api/sports/${id}/athletes`, 'sport-athletes'],
    ['/api/athletes/', 'athletes-list'],
    ['/api/sports/', 'sports-list'],
    [`/api/sports/${id}`, 'sport-detail'],
    ['/api/competitions/', 'competitions-list'],
    ['/api/sports/', 'sports-list'],
  ];

  
  for (const [path, name] of reads) {
    const response = http.get(
      `${BASE_URL}${path}`,
      { tags: { name: `GET ${name}` } }
    );

    check(response, {
      'read returned 200': (r) => r.status === 200,
    });

    if (path === '/api/sports/') {
      const cacheStatus =
        response.headers['X-Cache'] ||
        response.headers['x-cache'];

      cacheHitRate.add(cacheStatus === 'HIT');

      if (cacheStatus !== 'HIT') {
        sportsDbReads.add(1);
      }
    }
  }


  sleep(1);
}
