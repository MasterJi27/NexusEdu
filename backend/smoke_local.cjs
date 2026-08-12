/* Local full-stack smoke: register → login → AI endpoints → leaderboard guard */
const BASE = 'http://localhost:8080/api';
const email = `smoke_${Date.now()}@test.dev`;

async function call(path, { method = 'POST', body, token } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json };
}

(async () => {
  const results = [];
  const t = (name, ok, extra = '') => { results.push(`${ok ? 'PASS' : 'FAIL'} ${name} ${extra}`); };

  let r = await call('/health', { method: 'GET' });
  t('health', r.status === 200, `-> ${JSON.stringify(r.json)}`);

  r = await call('/auth/signup', { body: { name: 'Smoke User', email, password: 'smoke12345' } });
  t('signup', r.status === 201, `-> ${r.status}`);
  const uid = r.json?.user?.id;
  t('signup has id', !!uid, uid ? `uid=${uid}` : '');

  r = await call('/auth/login', { body: { email, password: 'smoke12345' } });
  const token = r.json?.token || r.json?.accessToken;
  t('login', r.status === 200 && !!token, `-> ${r.status}`);
  if (!token) { console.log(results.join('\n')); return; }

  r = await call('/users/leaderboard', { method: 'GET', token });
  t('leaderboard (auth)', r.status === 200, `-> ${r.status} ${Array.isArray(r.json) ? 'array' : ''}`);

  r = await call('/users/leaderboard', { method: 'GET' });
  t('leaderboard 401 w/o token', r.status === 401, `-> ${r.status}`);

  r = await call('/ai/agent', {
    token,
    body: { messages: [{ role: 'user', content: 'Tell me in one sentence what a plant needs to grow.' }] },
  });
  const reply = r.json?.choices?.[0]?.message?.content ?? r.json?.reply;
  t('ai/agent', r.status === 200 && typeof reply === 'string', `-> ${r.status} reply=${typeof reply === 'string' ? reply.slice(0, 60) : JSON.stringify(r.json).slice(0, 100)}`);

  r = await call('/ai/generate-quiz', {
    token,
    body: { topic: 'Photosynthesis', subject: 'Science', gradeLevel: 'Grade 5', count: 3 },
  });
  const q = r.json?.questions ?? r.json;
  t('ai/generate-quiz', r.status === 200 && Array.isArray(q), `-> ${r.status} questions=${Array.isArray(q) ? q.length : '?'}`);

  r = await call('/ai/grade-assignment', {
    token,
    body: { title: 'Essay', content: 'Plants need sunlight water and soil. Photosynthesis makes food.', maxScore: 10 },
  });
  const rubric = r.json?.rubric ?? r.json?.choices?.[0]?.message?.content ?? r.json;
  const rubricOk = typeof rubric === 'string' || (rubric && typeof rubric === 'object' && 'score' in rubric);
  t('ai/grade-assignment', r.status === 200 && rubricOk, `-> ${r.status} rubric=${rubricOk ? 'yes' : r.json?.error ?? JSON.stringify(r.json).slice(0, 80)}`);

  r = await call('/ai/parent-digest', { method: 'GET', token });
  t('ai/parent-digest', [200, 404, 409].includes(r.status), `-> ${r.status}`);

  r = await call('/ai/speech', {
    token,
    body: { text: 'Hello', voice: 'hannah' },
  });
  // Expected: 200 with audio/wav. 502 + terms-acceptance detail = old blocked state.
  const ttsOk = r.status === 200;
  t('ai/speech (TTS)', ttsOk, `-> ${r.status} ${ttsOk ? '(wav)' : String(r.json?.details ?? r.json?.error ?? '').slice(0, 100)}`);

  console.log(results.join('\n'));
})().catch((e) => { console.error('SMOKE CRASH:', e.message); process.exit(1); });
