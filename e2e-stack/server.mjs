/**
 * MokuTomo E2E用 Supabase互換エミュレータ (Docker不要)
 *
 * 素のPostgreSQL + このサーバー1本で、アプリを実際に動かしてE2Eテストを行う。
 *   - /rest/v1/*  : PostgRESTのサブセット (RLS/RPCは本物のPostgreSQLが実行する)
 *   - /auth/v1/*  : GoTrueのサブセット (パスワード認証・JWT発行。auth.usersへ書き込み
 *                    するため handle_new_user トリガも本物が動く)
 *   - /realtime/v1/websocket : Phoenixチャネルのサブセット (broadcast/presence)
 *
 * 本番のSupabaseの代替ではない。E2E・ローカル開発専用。
 */
import { createServer } from 'node:http';
import crypto from 'node:crypto';
import pg from 'pg';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.EMU_PORT || 54321);
const DB_URL = process.env.EMU_DB_URL || 'postgresql://postgres@127.0.0.1:55432/mokutomo';
const SECRET = process.env.EMU_JWT_SECRET || 'mokutomo-e2e-jwt-secret-at-least-32-chars!!';

const pool = new pg.Pool({ connectionString: DB_URL, max: 10 });

// ---------------- JWT (HS256) ----------------
const b64u = (buf) => Buffer.from(buf).toString('base64url');
function signJwt(claims, expiresSec = 60 * 60 * 24) {
  const now = Math.floor(Date.now() / 1000);
  const payload = { iat: now, exp: now + expiresSec, iss: 'mokutomo-e2e', ...claims };
  const head = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64u(JSON.stringify(payload));
  const sig = crypto.createHmac('sha256', SECRET).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}
function verifyJwt(token) {
  try {
    const [head, body, sig] = token.split('.');
    const expect = crypto.createHmac('sha256', SECRET).update(`${head}.${body}`).digest('base64url');
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expect))) return null;
    const claims = JSON.parse(Buffer.from(body, 'base64url').toString());
    if (claims.exp && claims.exp < Date.now() / 1000) return null;
    return claims;
  } catch {
    return null;
  }
}
export const ANON_KEY = signJwt({ role: 'anon' }, 10 * 365 * 24 * 3600);
export const SERVICE_KEY = signJwt({ role: 'service_role' }, 10 * 365 * 24 * 3600);

// ---------------- ユーティリティ ----------------
const IDENT = /^[a-zA-Z_][a-zA-Z0-9_]*$/;
function ident(name) {
  if (!IDENT.test(name)) throw httpError(400, 'invalid identifier: ' + name);
  return `"${name}"`;
}
function httpError(status, message, code = 'PGRST000') {
  const e = new Error(message);
  e.status = status;
  e.code = code;
  return e;
}
async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks).toString();
  return raw ? JSON.parse(raw) : null;
}
function send(res, status, body, headers = {}) {
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
      'authorization, apikey, content-type, prefer, accept, accept-profile, content-profile, x-client-info, x-supabase-api-version',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Expose-Headers': 'content-range',
  };
  if (body === undefined || body === null) {
    res.writeHead(status, { ...cors, ...headers });
    res.end();
  } else {
    res.writeHead(status, { 'Content-Type': 'application/json', ...cors, ...headers });
    res.end(JSON.stringify(body));
  }
}

// リクエストのJWTからロールを決めてクエリを実行 (RLSは本物のPostgreSQLが評価)
async function withRole(req, fn) {
  const authHeader = req.headers.authorization ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  const claims = token ? verifyJwt(token) : null;
  const role = ['anon', 'authenticated', 'service_role'].includes(claims?.role)
    ? claims.role
    : 'anon';
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query(`select set_config('request.jwt.claims', $1, true)`, [
      claims ? JSON.stringify(claims) : '',
    ]);
    await client.query(`set local role ${role}`);
    const result = await fn(client, claims);
    await client.query('commit');
    return result;
  } catch (e) {
    await client.query('rollback').catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}

// ---------------- PostgRESTサブセット ----------------
const OPS = {
  eq: '=',
  neq: '<>',
  gt: '>',
  gte: '>=',
  lt: '<',
  lte: '<=',
  like: 'like',
  ilike: 'ilike',
};

function parseFilters(searchParams) {
  const where = [];
  const params = [];
  let order = '';
  let limit = '';
  let offset = '';
  let select = '*';
  for (const [key, value] of searchParams.entries()) {
    if (key === 'select') {
      const cols = value.split(',').map((c) => c.trim());
      select = cols.map((c) => (c === '*' ? '*' : ident(c))).join(', ');
      continue;
    }
    if (key === 'order') {
      order =
        ' order by ' +
        value
          .split(',')
          .map((part) => {
            const [col, ...mods] = part.split('.');
            let s = ident(col);
            if (mods.includes('desc')) s += ' desc';
            else s += ' asc';
            if (mods.includes('nullsfirst')) s += ' nulls first';
            if (mods.includes('nullslast')) s += ' nulls last';
            return s;
          })
          .join(', ');
      continue;
    }
    if (key === 'limit') {
      limit = ` limit ${Number(value) || 0}`;
      continue;
    }
    if (key === 'offset') {
      offset = ` offset ${Number(value) || 0}`;
      continue;
    }
    if (key === 'on_conflict' || key === 'columns') continue;
    // col=op.value
    const dot = value.indexOf('.');
    if (dot < 0) throw httpError(400, `unsupported filter: ${key}=${value}`);
    const op = value.slice(0, dot);
    const raw = value.slice(dot + 1);
    const col = ident(key);
    if (op === 'is') {
      if (raw === 'null') where.push(`${col} is null`);
      else if (raw === 'not.null') where.push(`${col} is not null`);
      else if (raw === 'true' || raw === 'false') where.push(`${col} is ${raw}`);
      else throw httpError(400, `unsupported is filter: ${raw}`);
      continue;
    }
    if (op === 'in') {
      const items = raw.replace(/^\(/, '').replace(/\)$/, '').split(',').map((s) => {
        const t = s.trim();
        return t.startsWith('"') ? JSON.parse(t) : t;
      });
      params.push(items);
      where.push(`${col} = any($${params.length})`);
      continue;
    }
    if (op === 'not') {
      // not.is.null 等 (今回はnot.is.nullのみ対応)
      if (raw === 'is.null') {
        where.push(`${col} is not null`);
        continue;
      }
      throw httpError(400, `unsupported not filter: ${raw}`);
    }
    const sqlOp = OPS[op];
    if (!sqlOp) throw httpError(400, `unsupported operator: ${op}`);
    params.push(op === 'like' || op === 'ilike' ? raw.replaceAll('*', '%') : raw);
    where.push(`${col} ${sqlOp} $${params.length}`);
  }
  return {
    select,
    where: where.length ? ' where ' + where.join(' and ') : '',
    params,
    order,
    limit,
    offset,
  };
}

function wantsSingle(req) {
  return (req.headers.accept ?? '').includes('vnd.pgrst.object+json');
}
function wantsRepresentation(req) {
  return (req.headers.prefer ?? '').includes('return=representation');
}

function singleOr406(rows, res) {
  if (rows.length === 1) return send(res, 200, rows[0]);
  return send(res, 406, {
    code: 'PGRST116',
    message: 'JSON object requested, multiple (or no) rows returned',
    details: `The result contains ${rows.length} rows`,
    hint: null,
  });
}

// RPC: 関数シグネチャをカタログから取得してキャスト付き named notation で呼ぶ
const fnCache = new Map();
async function getFnInfo(client, fname) {
  if (fnCache.has(fname)) return fnCache.get(fname);
  const { rows } = await client.query(
    `select p.proretset as retset, p.prorettype::regtype::text as rettype,
            coalesce(p.proargnames, '{}') as argnames,
            (select coalesce(array_agg(t::regtype::text), '{}') from unnest(p.proargtypes) t) as argtypes
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = $1
     limit 1`,
    [fname]
  );
  if (rows.length === 0) throw httpError(404, `function public.${fname} not found`, 'PGRST202');
  fnCache.set(fname, rows[0]);
  return rows[0];
}

async function handleRpc(req, res, fname, body) {
  if (!IDENT.test(fname)) return send(res, 400, { message: 'bad function name' });
  try {
    const result = await withRole(req, async (client) => {
      const info = await getFnInfo(client, fname);
      const args = body ?? {};
      const parts = [];
      const params = [];
      for (const [k, v] of Object.entries(args)) {
        const idx = info.argnames.indexOf(k);
        if (idx < 0) throw httpError(400, `unknown argument ${k} for ${fname}`);
        const type = info.argtypes[idx] ?? 'text';
        params.push(v === undefined ? null : v);
        parts.push(`${ident(k)} => $${params.length}::${type}`);
      }
      const call = `public.${ident(fname)}(${parts.join(', ')})`;
      if (info.retset) {
        const { rows } = await client.query(
          `select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) as v from ${call} t`,
          params
        );
        return rows[0].v;
      }
      if (info.rettype === 'void') {
        await client.query(`select ${call}`, params);
        return null;
      }
      const { rows } = await client.query(`select to_jsonb(${call}) as v`, params);
      return rows[0].v;
    });
    return send(res, 200, result);
  } catch (e) {
    return send(res, e.status ?? 400, {
      code: e.code ?? 'P0001',
      message: e.message,
      details: e.detail ?? null,
      hint: e.hint ?? null,
    });
  }
}

async function handleRest(req, res, url) {
  const table = url.pathname.replace('/rest/v1/', '').replace(/\/$/, '');
  if (table.startsWith('rpc/')) {
    const body = req.method === 'POST' ? await readBody(req) : {};
    return handleRpc(req, res, table.slice(4), body);
  }
  if (!IDENT.test(table)) return send(res, 404, { message: 'not found' });
  const t = `public.${ident(table)}`;

  try {
    const q = parseFilters(url.searchParams);
    if (req.method === 'GET' || req.method === 'HEAD') {
      const rows = await withRole(req, async (client) => {
        const { rows } = await client.query(
          `select ${q.select} from ${t}${q.where}${q.order}${q.limit}${q.offset}`,
          q.params
        );
        return rows;
      });
      if (wantsSingle(req)) return singleOr406(rows, res);
      return send(res, 200, rows);
    }
    if (req.method === 'POST') {
      const body = await readBody(req);
      const items = Array.isArray(body) ? body : [body];
      if (items.length === 0) return send(res, 201, wantsRepresentation(req) ? [] : undefined);
      const cols = Object.keys(items[0]);
      cols.forEach(ident);
      const params = [];
      const valuesSql = items
        .map(
          (item) =>
            '(' +
            cols
              .map((c) => {
                const v = item[c];
                params.push(v !== null && typeof v === 'object' ? JSON.stringify(v) : v);
                return `$${params.length}`;
              })
              .join(', ') +
            ')'
        )
        .join(', ');
      const returning = wantsRepresentation(req) ? ' returning *' : '';
      const rows = await withRole(req, async (client) => {
        const { rows } = await client.query(
          `insert into ${t} (${cols.map(ident).join(', ')}) values ${valuesSql}${returning}`,
          params
        );
        return rows;
      });
      if (!wantsRepresentation(req)) return send(res, 201, undefined);
      if (wantsSingle(req)) return singleOr406(rows, res);
      return send(res, 201, rows);
    }
    if (req.method === 'PATCH') {
      const body = await readBody(req);
      const cols = Object.keys(body ?? {});
      if (cols.length === 0) return send(res, 200, []);
      const params = [...q.params];
      const sets = cols
        .map((c) => {
          const v = body[c];
          params.push(v !== null && typeof v === 'object' ? JSON.stringify(v) : v);
          return `${ident(c)} = $${params.length}`;
        })
        .join(', ');
      const returning = wantsRepresentation(req) ? ' returning *' : '';
      const rows = await withRole(req, async (client) => {
        const { rows } = await client.query(`update ${t} set ${sets}${q.where}${returning}`, params);
        return rows;
      });
      if (!wantsRepresentation(req)) return send(res, 204, undefined);
      if (wantsSingle(req)) return singleOr406(rows, res);
      return send(res, 200, rows);
    }
    if (req.method === 'DELETE') {
      await withRole(req, (client) => client.query(`delete from ${t}${q.where}`, q.params));
      return send(res, 204, undefined);
    }
    return send(res, 405, { message: 'method not allowed' });
  } catch (e) {
    return send(res, e.status ?? 400, {
      code: e.code ?? 'PGRST000',
      message: e.message,
      details: e.detail ?? null,
      hint: e.hint ?? null,
    });
  }
}

// ---------------- GoTrueサブセット ----------------
function userResponse(row) {
  return {
    id: row.id,
    aud: 'authenticated',
    role: 'authenticated',
    email: row.email,
    email_confirmed_at: row.email_confirmed_at,
    app_metadata: { provider: 'email', providers: ['email'] },
    user_metadata: row.raw_user_meta_data ?? {},
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}
function sessionResponse(row) {
  const expiresIn = 24 * 3600;
  const access = signJwt(
    { sub: row.id, role: 'authenticated', email: row.email, aud: 'authenticated' },
    expiresIn
  );
  const refresh = signJwt({ sub: row.id, typ: 'refresh' }, 30 * 24 * 3600);
  return {
    access_token: access,
    token_type: 'bearer',
    expires_in: expiresIn,
    expires_at: Math.floor(Date.now() / 1000) + expiresIn,
    refresh_token: refresh,
    user: userResponse(row),
  };
}
const authError = (res, status, msg, code) =>
  send(res, status, { code: status, error_code: code, msg, error_description: msg });

async function handleAuth(req, res, url) {
  const path = url.pathname.replace('/auth/v1', '');

  if (path === '/health') return send(res, 200, { name: 'mokutomo-auth-emulator' });

  if (path === '/signup' && req.method === 'POST') {
    const body = await readBody(req);
    const email = String(body?.email ?? '').toLowerCase();
    const password = String(body?.password ?? '');
    const meta = body?.data ?? {};
    if (!email || password.length < 6) return authError(res, 400, 'invalid email or password', 'validation_failed');
    const client = await pool.connect();
    try {
      const dup = await client.query('select 1 from auth.users where email = $1', [email]);
      if (dup.rows.length > 0) {
        return authError(res, 422, 'User already registered', 'user_already_exists');
      }
      const { rows } = await client.query(
        `insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
           raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
           confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
         values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
           $1, crypt($2, gen_salt('bf')), now(),
           '{"provider":"email","providers":["email"]}', $3, now(), now(), '', '', '', '', '')
         returning *`,
        [email, password, JSON.stringify(meta)]
      );
      const user = rows[0];
      await client.query(
        `insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
         values (gen_random_uuid(), $1, $2, $3, 'email', now(), now(), now())`,
        [user.id, String(user.id), JSON.stringify({ sub: user.id, email, email_verified: true })]
      );
      return send(res, 200, sessionResponse(user));
    } finally {
      client.release();
    }
  }

  if (path === '/token' && req.method === 'POST') {
    const grant = url.searchParams.get('grant_type');
    const body = await readBody(req);
    if (grant === 'password') {
      const email = String(body?.email ?? '').toLowerCase();
      const password = String(body?.password ?? '');
      const { rows } = await pool.query(
        `select * from auth.users where email = $1 and encrypted_password = crypt($2, encrypted_password)`,
        [email, password]
      );
      if (rows.length === 0) {
        return authError(res, 400, 'Invalid login credentials', 'invalid_credentials');
      }
      return send(res, 200, sessionResponse(rows[0]));
    }
    if (grant === 'refresh_token') {
      const claims = verifyJwt(String(body?.refresh_token ?? ''));
      if (!claims || claims.typ !== 'refresh') {
        return authError(res, 400, 'Invalid Refresh Token', 'refresh_token_not_found');
      }
      const { rows } = await pool.query('select * from auth.users where id = $1', [claims.sub]);
      if (rows.length === 0) return authError(res, 400, 'user not found', 'user_not_found');
      return send(res, 200, sessionResponse(rows[0]));
    }
    return authError(res, 400, 'unsupported grant type', 'unsupported_grant_type');
  }

  if (path === '/user' && req.method === 'GET') {
    const token = (req.headers.authorization ?? '').replace('Bearer ', '');
    const claims = verifyJwt(token);
    if (!claims?.sub) return authError(res, 401, 'invalid JWT', 'bad_jwt');
    const { rows } = await pool.query('select * from auth.users where id = $1', [claims.sub]);
    if (rows.length === 0) return authError(res, 404, 'user not found', 'user_not_found');
    return send(res, 200, userResponse(rows[0]));
  }

  if (path === '/logout' && req.method === 'POST') return send(res, 204, undefined);
  if (path === '/recover' && req.method === 'POST') return send(res, 200, {});

  const adminUser = path.match(/^\/admin\/users\/([0-9a-f-]+)$/);
  if (adminUser && req.method === 'DELETE') {
    const token = (req.headers.authorization ?? '').replace('Bearer ', '');
    const claims = verifyJwt(token);
    if (claims?.role !== 'service_role') return authError(res, 401, 'service role required', 'not_admin');
    await pool.query('delete from auth.users where id = $1', [adminUser[1]]);
    return send(res, 200, {});
  }

  return send(res, 404, { message: 'not found: ' + path });
}

// ---------------- Realtimeサブセット (Phoenixチャネル互換) ----------------
// フレーム: JSON配列 [join_ref, ref, topic, event, payload]
// クライアント→サーバーのbroadcastのみバイナリ(kind=3)で届くのでデコードする
const topics = new Map(); // topic -> Map<ws, {key, joinRef, meta: payload|null, phxRef}>
let phxRefCounter = 1;

function wsSend(ws, joinRef, ref, topic, event, payload) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify([joinRef, ref, topic, event, payload]));
  }
}
function presenceStateOf(topic) {
  const members = topics.get(topic);
  const state = {};
  if (!members) return state;
  for (const info of members.values()) {
    if (info.meta) {
      // 同じキー(=同じユーザー)の複数接続はmetasに集約する (多重入室検知に必要)
      state[info.key] ??= { metas: [] };
      state[info.key].metas.push({ phx_ref: info.phxRef, ...info.meta });
    }
  }
  return state;
}
function broadcastToTopic(topic, excludeWs, frame) {
  const members = topics.get(topic);
  if (!members) return;
  for (const ws of members.keys()) {
    if (ws !== excludeWs) ws.send(JSON.stringify(frame));
  }
}
function decodeBinaryPush(buf) {
  // kind(1) joinRefLen refLen topicLen eventLen metaLen encoding + データ
  const kind = buf.readUInt8(0);
  if (kind !== 3) return null;
  const joinRefLen = buf.readUInt8(1);
  const refLen = buf.readUInt8(2);
  const topicLen = buf.readUInt8(3);
  const eventLen = buf.readUInt8(4);
  const metaLen = buf.readUInt8(5);
  const encoding = buf.readUInt8(6);
  let off = 7;
  const joinRef = buf.subarray(off, off + joinRefLen).toString(); off += joinRefLen;
  const ref = buf.subarray(off, off + refLen).toString(); off += refLen;
  const topic = buf.subarray(off, off + topicLen).toString(); off += topicLen;
  const event = buf.subarray(off, off + eventLen).toString(); off += eventLen;
  off += metaLen; // metadataは使用しない
  const payloadRaw = buf.subarray(off);
  const payload = encoding === 1 ? JSON.parse(payloadRaw.toString()) : payloadRaw;
  return { joinRef, ref, topic, event, payload };
}

function handleRealtimeMessage(ws, msg) {
  const [joinRef, ref, topic, event, payload] = msg;

  if (topic === 'phoenix' && event === 'heartbeat') {
    return wsSend(ws, null, ref, 'phoenix', 'phx_reply', { status: 'ok', response: {} });
  }
  if (event === 'phx_join') {
    if (!topics.has(topic)) topics.set(topic, new Map());
    const key = payload?.config?.presence?.key || crypto.randomUUID();
    topics.get(topic).set(ws, { key, joinRef, meta: null, phxRef: String(phxRefCounter++) });
    ws.joinedTopics ??= new Set();
    ws.joinedTopics.add(topic);
    wsSend(ws, joinRef, ref, topic, 'phx_reply', { status: 'ok', response: { postgres_changes: [] } });
    // 参加直後に現在のpresence状態を送る
    wsSend(ws, joinRef, null, topic, 'presence_state', presenceStateOf(topic));
    return;
  }
  if (event === 'phx_leave') {
    leaveTopic(ws, topic);
    return wsSend(ws, joinRef, ref, topic, 'phx_reply', { status: 'ok', response: {} });
  }
  if (event === 'access_token') {
    return wsSend(ws, joinRef, ref, topic, 'phx_reply', { status: 'ok', response: {} });
  }
  if (event === 'presence') {
    const members = topics.get(topic);
    const info = members?.get(ws);
    if (info) {
      if (payload?.event === 'track') {
        const hadMeta = !!info.meta;
        info.meta = payload.payload ?? {};
        info.phxRef = String(phxRefCounter++);
        const joins = { [info.key]: { metas: [{ phx_ref: info.phxRef, ...info.meta }] } };
        const frame = [null, null, topic, 'presence_diff', { joins, leaves: hadMeta ? { [info.key]: { metas: [{ phx_ref: 'stale' }] } } : {} }];
        for (const w of members.keys()) w.send(JSON.stringify(frame));
      } else if (payload?.event === 'untrack') {
        const leaves = info.meta
          ? { [info.key]: { metas: [{ phx_ref: info.phxRef, ...info.meta }] } }
          : {};
        info.meta = null;
        const frame = [null, null, topic, 'presence_diff', { joins: {}, leaves }];
        for (const w of members.keys()) w.send(JSON.stringify(frame));
      }
    }
    return wsSend(ws, joinRef, ref, topic, 'phx_reply', { status: 'ok', response: {} });
  }
  if (event === 'broadcast') {
    // テキスト経由のbroadcast (旧形式)
    broadcastToTopic(topic, ws, [null, null, topic, 'broadcast', payload]);
    if (ref) wsSend(ws, joinRef, ref, topic, 'phx_reply', { status: 'ok', response: {} });
    return;
  }
}

function leaveTopic(ws, topic) {
  const members = topics.get(topic);
  const info = members?.get(ws);
  if (!members || !info) return;
  members.delete(ws);
  if (info.meta) {
    const frame = [null, null, topic, 'presence_diff', {
      joins: {},
      leaves: { [info.key]: { metas: [{ phx_ref: info.phxRef, ...info.meta }] } },
    }];
    for (const w of members.keys()) w.send(JSON.stringify(frame));
  }
  if (members.size === 0) topics.delete(topic);
}

// ---------------- HTTPサーバー ----------------
const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  if (req.method === 'OPTIONS') return send(res, 204, undefined);
  try {
    if (url.pathname.startsWith('/rest/v1/')) return await handleRest(req, res, url);
    if (url.pathname.startsWith('/auth/v1/')) return await handleAuth(req, res, url);
    if (url.pathname === '/') return send(res, 200, { name: 'mokutomo-e2e-stack', anon_key: ANON_KEY });
    return send(res, 404, { message: 'not found' });
  } catch (e) {
    return send(res, 500, { message: e.message });
  }
});

const wss = new WebSocketServer({ noServer: true });
server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  if (!url.pathname.startsWith('/realtime/v1/websocket')) {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => {
    ws.on('message', (data, isBinary) => {
      try {
        if (isBinary) {
          const decoded = decodeBinaryPush(Buffer.from(data));
          if (decoded) {
            // バイナリbroadcast → 他メンバーへテキスト形式で中継
            broadcastToTopic(decoded.topic, ws, [
              null, null, decoded.topic, 'broadcast',
              { type: 'broadcast', event: decoded.event, payload: decoded.payload },
            ]);
            if (decoded.ref) {
              wsSend(ws, decoded.joinRef || null, decoded.ref, decoded.topic, 'phx_reply', { status: 'ok', response: {} });
            }
          }
          return;
        }
        handleRealtimeMessage(ws, JSON.parse(data.toString()));
      } catch (e) {
        console.error('[realtime] message error:', e.message);
      }
    });
    ws.on('close', () => {
      for (const topic of ws.joinedTopics ?? []) leaveTopic(ws, topic);
    });
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`mokutomo e2e-stack listening on http://127.0.0.1:${PORT}`);
  console.log(`ANON_KEY=${ANON_KEY}`);
  console.log(`SERVICE_KEY=${SERVICE_KEY}`);
});
