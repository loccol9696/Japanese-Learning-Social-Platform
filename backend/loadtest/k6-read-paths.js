// Kiểm tra tải các đường đọc chính của backend bằng k6 (https://k6.io).
//
//   k6 run -e BASE_URL=http://localhost:8080 -e LOAD_USER=user1 -e LOAD_PASSWORD='Abc12345!' backend/loadtest/k6-read-paths.js
//
// Chạy backend với APP_DIAGNOSTICS_QUERY_COUNT=true để mỗi request ghi một dòng "[query-count]" — so số
// truy vấn/request trước và sau khi tối ưu. Đăng nhập chỉ thực hiện một lần trong setup() vì endpoint login
// bị giới hạn 30 lần / 5 phút / IP (AuthRateLimitFilter); đừng bỏ giới hạn này khi đo.
import http from 'k6/http';
import { check, group, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const API = `${BASE_URL}/api/v1`;

export const options = {
  scenarios: {
    readers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '20s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{endpoint:feed}': ['p(95)<500'],
    'http_req_duration{endpoint:comments}': ['p(95)<400'],
    'http_req_duration{endpoint:flashcard_sets}': ['p(95)<400'],
    'http_req_duration{endpoint:notifications}': ['p(95)<300'],
  },
};

export function setup() {
  const res = http.post(
    `${API}/auth/login`,
    JSON.stringify({ usernameOrEmail: __ENV.LOAD_USER, password: __ENV.LOAD_PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  if (!check(res, { 'login 200': (r) => r.status === 200 })) {
    throw new Error(`Đăng nhập thất bại (${res.status}): đặt LOAD_USER và LOAD_PASSWORD`);
  }
  return { token: res.json('data.accessToken') };
}

export default function (data) {
  const params = (endpoint) => ({
    headers: { Authorization: `Bearer ${data.token}` },
    tags: { endpoint },
  });

  group('feed', () => {
    const feed = http.get(`${API}/videos?feed=for-you&page=0&size=10`, params('feed'));
    check(feed, { 'feed 200': (r) => r.status === 200 });

    const videos = feed.status === 200 ? feed.json('data.content') : [];
    if (videos && videos.length > 0) {
      const id = videos[Math.floor(Math.random() * videos.length)].id;
      const comments = http.get(`${API}/videos/${id}/comments`, params('comments'));
      check(comments, { 'comments 200': (r) => r.status === 200 });
    }
  });

  group('flashcards', () => {
    const sets = http.get(`${API}/flashcards/sets?page=0&size=20`, params('flashcard_sets'));
    check(sets, { 'sets 200': (r) => r.status === 200 });
    const due = http.get(`${API}/flashcards/study/due-session`, params('flashcard_due'));
    check(due, { 'due 200': (r) => r.status === 200 });
  });

  group('social', () => {
    const search = http.get(`${API}/users/search?q=ta&page=0&size=10`, params('user_search'));
    check(search, { 'search 200': (r) => r.status === 200 });
    const followers = http.get(`${API}/users/me/followers`, params('followers'));
    check(followers, { 'followers 200': (r) => r.status === 200 });
  });

  group('notifications', () => {
    const unread = http.get(`${API}/notifications/unread-count`, params('notifications'));
    check(unread, { 'unread 200': (r) => r.status === 200 });
  });

  sleep(1);
}
