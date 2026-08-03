const http = require("node:http");

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "127.0.0.1";
const BEARER_TOKEN = process.env.X_BEARER_TOKEN;
const HANDLE = "thsottiaux";
const RULE_TAG = "tibo-reset-watch";
const RULE_VALUE = `from:${HANDLE} -is:retweet`;
const MAX_POSTS = 100;
const API_ROOT = "https://api.x.com/2";
const STREAM_URL = `${API_ROOT}/tweets/search/stream?tweet.fields=created_at,author_id,referenced_tweets`;

const posts = new Map();
const subscribers = new Set();
const state = {
  connected: false,
  lastEventAt: null,
  lastKeepAliveAt: null,
  lastError: null,
  fetchedAt: null,
  userId: null,
};

function authHeaders(extra = {}) {
  return {
    Authorization: `Bearer ${BEARER_TOKEN}`,
    ...extra,
  };
}

async function xJSON(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: authHeaders(options.headers),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`X API ${response.status}: ${body.slice(0, 300)}`);
  }
  return response.json();
}

function canonicalPost(post) {
  if (!post || typeof post.id !== "string" || typeof post.text !== "string") return null;
  if (post.author_id && post.author_id !== state.userId) return null;

  return {
    id: post.id,
    url: `https://x.com/${HANDLE}/status/${post.id}`,
    text: post.text,
    at: post.created_at || new Date().toISOString(),
    kind: "other",
    reset_verification_status: null,
  };
}

function remember(post) {
  const normalized = canonicalPost(post);
  if (!normalized) return null;
  posts.set(normalized.id, normalized);

  const ordered = [...posts.values()]
    .sort((left, right) => String(right.at).localeCompare(String(left.at)))
    .slice(0, MAX_POSTS);
  posts.clear();
  ordered.forEach((item) => posts.set(item.id, item));
  return normalized;
}

function orderedPosts() {
  return [...posts.values()].sort((left, right) => String(right.at).localeCompare(String(left.at)));
}

function writeJSON(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "Access-Control-Allow-Origin": "*",
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
  });
  response.end(JSON.stringify(payload));
}

function feedSnapshot() {
  const tweets = orderedPosts();
  return {
    version: 1,
    fetched_at: state.fetchedAt || new Date().toISOString(),
    source: "x-filtered-stream",
    source_scope: "timeline",
    stale: !state.connected,
    profile: { handle: HANDLE },
    newest_post_at: tweets[0]?.at || null,
    tweets,
  };
}

function healthPayload() {
  return {
    ok: Boolean(BEARER_TOKEN) && state.connected && state.lastError === null,
    provider: "x-filtered-stream",
    handle: HANDLE,
    rule: RULE_VALUE,
    connected: state.connected,
    last_event_at: state.lastEventAt,
    last_keep_alive_at: state.lastKeepAliveAt,
    last_error: state.lastError,
    post_count: posts.size,
  };
}

function broadcast(event) {
  const message = `data: ${JSON.stringify(event)}\n\n`;
  for (const response of subscribers) response.write(message);
}

async function ensureRule() {
  const current = await xJSON(`${API_ROOT}/tweets/search/stream/rules`);
  const existing = (current.data || []).find((rule) => rule.tag === RULE_TAG);
  if (existing?.value === RULE_VALUE) return;

  if (existing) {
    await xJSON(`${API_ROOT}/tweets/search/stream/rules`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ delete: { ids: [existing.id] } }),
    });
  }

  await xJSON(`${API_ROOT}/tweets/search/stream/rules`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ add: [{ value: RULE_VALUE, tag: RULE_TAG }] }),
  });
}

async function bootstrapTimeline() {
  const user = await xJSON(`${API_ROOT}/users/by/username/${HANDLE}`);
  state.userId = user.data?.id;
  if (!state.userId) throw new Error("X API did not return Tibo's user id");

  const timeline = await xJSON(
    `${API_ROOT}/users/${state.userId}/tweets?max_results=100&exclude=retweets&tweet.fields=created_at,author_id,referenced_tweets`,
  );
  (timeline.data || []).forEach(remember);
}

async function consumeStream() {
  const response = await fetch(STREAM_URL, { headers: authHeaders() });
  if (!response.ok || !response.body) {
    throw new Error(`X stream HTTP ${response.status}`);
  }

  state.connected = true;
  state.lastError = null;
  let buffer = "";

  for await (const chunk of response.body) {
    buffer += Buffer.from(chunk).toString("utf8");
    let newlineIndex = buffer.indexOf("\n");
    while (newlineIndex >= 0) {
      const line = buffer.slice(0, newlineIndex).trim();
      buffer = buffer.slice(newlineIndex + 1);
      newlineIndex = buffer.indexOf("\n");

      if (!line) {
        state.lastKeepAliveAt = new Date().toISOString();
        continue;
      }

      const event = JSON.parse(line);
      const post = remember(event.data);
      state.lastEventAt = new Date().toISOString();
      state.fetchedAt = state.lastEventAt;
      if (post) broadcast({ type: "post", post });
    }
  }

  throw new Error("X stream closed");
}

async function runStream() {
  let delay = 1_000;
  while (true) {
    try {
      await consumeStream();
      delay = 1_000;
    } catch (error) {
      state.connected = false;
      state.lastError = error.message;
      broadcast({ type: "status", status: healthPayload() });
      await new Promise((resolve) => setTimeout(resolve, delay));
      delay = Math.min(delay * 2, 60_000);
    }
  }
}

function createServer() {
  return http.createServer((request, response) => {
    const requestURL = new URL(request.url, `http://${request.headers.host}`);

    if (request.method === "OPTIONS") {
      response.writeHead(204, {
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Origin": "*",
      });
      response.end();
      return;
    }

    if (request.method !== "GET") {
      writeJSON(response, 405, { error: "method_not_allowed" });
      return;
    }

    if (requestURL.pathname === "/health") {
      writeJSON(response, state.lastError ? 503 : 200, healthPayload());
      return;
    }

    if (requestURL.pathname === "/api/feed") {
      state.fetchedAt = new Date().toISOString();
      writeJSON(response, 200, feedSnapshot());
      return;
    }

    if (requestURL.pathname === "/events") {
      response.writeHead(200, {
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
        "Content-Type": "text/event-stream; charset=utf-8",
      });
      response.write(`data: ${JSON.stringify({ type: "status", status: healthPayload() })}\n\n`);
      subscribers.add(response);
      request.on("close", () => subscribers.delete(response));
      return;
    }

    writeJSON(response, 404, { error: "not_found" });
  });
}

async function start() {
  if (!BEARER_TOKEN) {
    throw new Error("Set X_BEARER_TOKEN before starting the stream worker.");
  }

  let delay = 1_000;
  while (true) {
    try {
      await ensureRule();
      await bootstrapTimeline();
      state.fetchedAt = new Date().toISOString();
      await runStream();
      delay = 1_000;
    } catch (error) {
      state.connected = false;
      state.lastError = error.message;
      await new Promise((resolve) => setTimeout(resolve, delay));
      delay = Math.min(delay * 2, 60_000);
    }
  }
}

const server = createServer();
server.listen(PORT, HOST, () => {
  console.log(`Tibo stream worker listening on http://${HOST}:${PORT}`);
  start().catch((error) => {
    state.lastError = error.message;
    console.error(error.message);
  });
});
