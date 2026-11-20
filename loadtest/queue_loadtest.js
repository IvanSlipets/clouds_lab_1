import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';


const BASE_URL = (__ENV.API_URL || '').replace(/\/+$/, '');
const RATE = Number(__ENV.QUEUE_RATE || 1);
const SMOKE = __ENV.SMOKE === '1';

const enqueueDuration = new Trend('async_enqueue_duration', true);

export const options = {
  scenarios: {
    async_sports_creation: {
      executor: 'ramping-arrival-rate',
      startRate: 0,
      timeUnit: '1s',
      preAllocatedVUs: 10,
      maxVUs: 30,

      stages: SMOKE
        ? [
            { duration: '5s', target: 1 },
            { duration: '20s', target: 1 },
            { duration: '5s', target: 0 },
          ]
        : [
            { duration: '3m', target: RATE },
            { duration: '5m', target: RATE },
            { duration: '2m', target: 0 },
          ],
    },
  },

  summaryTrendStats: [
    'avg',
    'min',
    'med',
    'p(90)',
    'p(95)',
    'p(99)',
    'max',
  ],

  thresholds: {
    http_req_failed: ['rate<0.05'],
    checks: ['rate>0.95'],
  },
};

export function setup() {
  if (!BASE_URL || !__ENV.API_PASSWORD) {
    throw new Error(
      'Set API_URL and API_PASSWORD in the environment'
    );
  }

  const response = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({
      username: __ENV.API_USER || 'admin',
      password: __ENV.API_PASSWORD,
    }),
    {
      headers: {
        'Content-Type': 'application/json',
      },
      tags: {
        name: 'POST /api/auth/login',
      },
      timeout: '15s',
    }
  );

  if (
    response.status !== 200 ||
    !response.json('access_token')
  ) {
    throw new Error(
      `JWT login failed: HTTP ${response.status}`
    );
  }

  return {
    token: response.json('access_token'),
  };
}

export default function (data) {
  const unique = `${Date.now()}-${__VU}-${__ITER}`;

  const response = http.post(
    `${BASE_URL}/api/jobs/sports`,
    JSON.stringify({
      name: `k6-async-${unique}`,
      description: 'Lab2 asynchronous worker scaling test',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${data.token}`,
        'Idempotency-Key': `k6-async-${unique}`,
      },
      tags: {
        name: 'POST /api/jobs/sports',
      },
      timeout: '15s',
    }
  );

  enqueueDuration.add(response.timings.duration);

  check(response, {
    'accepted (202)': (r) => r.status === 202,

    'has job_id': (r) =>
      r.status === 202 && Boolean(r.json('job_id')),
  });
}
