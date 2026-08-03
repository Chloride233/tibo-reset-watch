const FEED_ENDPOINT = window.TIBO_RESET_WATCH_CONFIG?.feedEndpoint || "https://codex-reset.com/api/feed";
const TIBO_HANDLE = "thsottiaux";
const NORMAL_INTERVAL_MS = 120_000;
const STORAGE_KEY = "tibo-reset-watch.web.v1";

const refs = {
  sourceIndicator: document.getElementById("source-indicator"),
  sourceState: document.getElementById("source-state"),
  checkNow: document.getElementById("check-now"),
  enableNotifications: document.getElementById("enable-notifications"),
  updatedMeta: document.getElementById("updated-meta"),
  latestTime: document.getElementById("latest-time"),
  latestText: document.getElementById("latest-text"),
  latestLink: document.getElementById("latest-link"),
  alertMode: document.getElementById("alert-mode"),
  alertCount: document.getElementById("alert-count"),
  alertsList: document.getElementById("alerts-list"),
  profileHandle: document.getElementById("profile-handle"),
  sourceScope: document.getElementById("source-scope"),
  lastChecked: document.getElementById("last-checked"),
  retryState: document.getElementById("retry-state"),
  errorBanner: document.getElementById("error-banner"),
  errorText: document.getElementById("error-text"),
};

const state = {
  polling: false,
  failures: 0,
  timer: null,
  posts: [],
  alerts: [],
  primed: false,
  seen: new Set(),
  mode: "possibleAndConfirmed",
};

const confirmedPhrases = [
  "i've reset usage limits",
  "i have reset usage limits",
  "we've reset usage limits",
  "we have reset usage limits",
  "usage limits have been reset",
  "usage limit has been reset",
  "usage limits reset for all",
  "reset usage limits for all",
  "reset the usage limits for all",
  "limits have been reset",
];

const quotaContextPhrases = [
  "usage limit",
  "usage limits",
  "limit reset",
  "quota",
  "codex",
  "chatgpt work",
  "banked reset",
];

const futurePhrases = [
  "will reset",
  "going to reset",
  "about to reset",
  "in a few hours",
  "next hour",
  "later today",
  "tomorrow",
  "feeling like a limit reset",
  "time for a reset",
  "more manual resets",
];

const noResetPhrases = [
  "no reset",
  "not a reset",
  "isn't a reset",
  "is not a reset",
  "not about to announce a reset",
];

function containsAny(text, phrases) {
  return phrases.some((phrase) => text.includes(phrase));
}

function isTiboPost(post) {
  if (!post || typeof post.id !== "string" || typeof post.url !== "string") return false;

  try {
    const url = new URL(post.url);
    const allowedHosts = new Set(["x.com", "www.x.com", "twitter.com", "www.twitter.com"]);
    const path = url.pathname.split("/").filter(Boolean);
    return allowedHosts.has(url.hostname.toLowerCase()) &&
      path.length >= 3 &&
      path[0].toLowerCase() === TIBO_HANDLE &&
      path[1].toLowerCase() === "status" &&
      path[2] === post.id;
  } catch {
    return false;
  }
}

function classify(post) {
  const text = String(post.text || "").toLowerCase();
  if (containsAny(text, noResetPhrases)) return null;

  const verification = post.reset_verification_status || post.reset_verification?.status;
  if (verification === "confirmed" || containsAny(text, confirmedPhrases)) {
    return { post, level: "confirmed", key: `${post.id}|confirmed` };
  }

  if (text.includes("reset") && containsAny(text, quotaContextPhrases) && containsAny(text, futurePhrases)) {
    return { post, level: "upcoming", key: `${post.id}|upcoming` };
  }

  return null;
}

function readStoredState() {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    state.primed = stored.primed === true;
    state.mode = stored.mode === "confirmedOnly" ? "confirmedOnly" : "possibleAndConfirmed";
    state.seen = new Set(Array.isArray(stored.seen) ? stored.seen : []);
  } catch {
    state.primed = false;
    state.mode = "possibleAndConfirmed";
    state.seen = new Set();
  }
  refs.alertMode.value = state.mode;
}

function saveStoredState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      primed: state.primed,
      mode: state.mode,
      seen: [...state.seen].slice(-200),
    }));
  } catch {
    // Private browsing or a blocked storage policy should not stop polling.
  }
}

function compactText(text, limit = 240) {
  const oneLine = String(text || "").replace(/\s+/g, " ").trim();
  return oneLine.length > limit ? `${oneLine.slice(0, limit - 1)}…` : oneLine;
}

function formatTime(value, fallback = "—") {
  if (!value) return fallback;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return fallback;
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function formatCheckedTime() {
  return new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(new Date());
}

function setSourceState(text, status = "loading") {
  refs.sourceState.textContent = text;
  refs.sourceIndicator.dataset.state = status;
}

function setError(message = "") {
  refs.errorBanner.hidden = !message;
  if (message) refs.errorText.textContent = message;
}

function retryIntervalMs(failureCount) {
  return Math.min(900_000, 60_000 * (2 ** Math.max(failureCount - 1, 0)));
}

function validateSnapshot(snapshot) {
  if (snapshot.stale) throw new Error("Feed 标记为过期");
  if (snapshot.source_scope?.toLowerCase() !== "timeline" ||
      snapshot.profile?.handle?.toLowerCase() !== TIBO_HANDLE) {
    throw new Error("Feed 身份不是 @thsottiaux timeline");
  }

  const sourcePosts = Array.isArray(snapshot.tweets) ? snapshot.tweets : [];
  const posts = sourcePosts.filter(isTiboPost);
  if (sourcePosts.length > 0 && posts.length === 0) {
    throw new Error("Feed 中没有通过作者校验的帖子");
  }
  return posts;
}

function updateLatest(posts) {
  const post = posts[0];
  if (!post) {
    refs.latestTime.textContent = "—";
    refs.latestText.textContent = "当前没有可展示的 Tibo 动态。";
    refs.latestLink.hidden = true;
    return;
  }

  refs.latestTime.textContent = formatTime(post.at);
  refs.latestText.textContent = compactText(post.text, 220);
  refs.latestLink.href = post.url;
  refs.latestLink.hidden = false;
}

function updateSourceFacts(snapshot, posts) {
  refs.profileHandle.textContent = `@${snapshot.profile.handle}`;
  refs.sourceScope.textContent = snapshot.source_scope;
  refs.lastChecked.textContent = formatCheckedTime();
  refs.retryState.textContent = "正常 · 2 分钟轮询";
  refs.updatedMeta.textContent = posts[0]?.at
    ? `最新帖子 ${formatTime(posts[0].at)} · 上游约每 15 分钟同步`
    : "没有可展示的 Tibo 动态 · 上游约每 15 分钟同步";
}

function createAlertRow(alert) {
  const row = document.createElement("article");
  row.className = `alert-row ${alert.level}`;

  const head = document.createElement("div");
  head.className = "alert-head";
  const kind = document.createElement("span");
  kind.className = "alert-kind";
  kind.textContent = alert.level === "confirmed" ? "CONFIRMED RESET" : "POSSIBLE RESET";
  const time = document.createElement("time");
  time.dateTime = alert.post.at || "";
  time.textContent = formatTime(alert.post.at);
  head.append(kind, time);

  const text = document.createElement("p");
  text.className = "alert-text";
  text.textContent = compactText(alert.post.text);

  const link = document.createElement("a");
  link.className = "alert-link";
  link.href = alert.post.url;
  link.target = "_blank";
  link.rel = "noopener noreferrer";
  link.textContent = "打开原帖 ↗";

  row.append(head, text, link);
  return row;
}

function renderAlerts() {
  refs.alertsList.replaceChildren();
  const visible = state.mode === "confirmedOnly"
    ? state.alerts.filter((alert) => alert.level === "confirmed")
    : state.alerts;
  refs.alertCount.textContent = `${visible.length} 条信号`;

  if (visible.length === 0) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    const title = document.createElement("strong");
    title.textContent = "还没有 reset 信号";
    const body = document.createElement("span");
    body.textContent = state.mode === "confirmedOnly" ? "当前只展示已经确认的 reset。" : "新信号会出现在这里。";
    empty.append(title, body);
    refs.alertsList.append(empty);
    refs.alertsList.setAttribute("aria-busy", "false");
    return;
  }

  visible.slice(0, 10).forEach((alert) => refs.alertsList.append(createAlertRow(alert)));
  refs.alertsList.setAttribute("aria-busy", "false");
}

function notificationAllowed(alert) {
  return state.mode === "possibleAndConfirmed" || alert.level === "confirmed";
}

function notifyAlert(alert) {
  if (!notificationAllowed(alert) || !("Notification" in window) || Notification.permission !== "granted") return;

  const notification = new Notification(
    alert.level === "confirmed" ? "Tibo：Codex reset 已确认" : "Tibo：可能有 Codex reset",
    { body: compactText(alert.post.text), tag: `tibo-reset-${alert.key}` },
  );
  notification.onclick = () => {
    window.focus();
    window.open(alert.post.url, "_blank", "noopener,noreferrer");
  };
}

function updateNotificationButton() {
  if (!("Notification" in window)) {
    refs.enableNotifications.textContent = "浏览器不支持通知";
    refs.enableNotifications.disabled = true;
  } else if (Notification.permission === "granted") {
    refs.enableNotifications.textContent = "系统通知已开启";
  } else if (Notification.permission === "denied") {
    refs.enableNotifications.textContent = "通知已被浏览器拒绝";
  }
}

async function requestNotifications() {
  if (!("Notification" in window)) return;
  await Notification.requestPermission();
  updateNotificationButton();
}

function scheduleNext(delayMs) {
  window.clearTimeout(state.timer);
  state.timer = window.setTimeout(() => poll(), delayMs);
}

async function poll() {
  if (state.polling) return;
  state.polling = true;
  refs.checkNow.disabled = true;
  refs.checkNow.textContent = "检查中…";
  setSourceState("正在读取 Tibo timeline", "loading");

  try {
    const response = await fetch(FEED_ENDPOINT, { cache: "no-store" });
    if (!response.ok) throw new Error(`Feed HTTP ${response.status}`);
    const snapshot = await response.json();
    const posts = validateSnapshot(snapshot);
    const alerts = posts.map(classify).filter(Boolean);
    state.posts = posts;
    state.alerts = alerts;
    state.failures = 0;

    updateLatest(posts);
    updateSourceFacts(snapshot, posts);
    renderAlerts();
    setSourceState(`正常 · ${posts.length} 条 Tibo 动态`, "ok");
    setError();

    if (!state.primed) {
      alerts.forEach((alert) => state.seen.add(alert.key));
      state.primed = true;
      saveStoredState();
    } else {
      const unseen = alerts.filter((alert) => !state.seen.has(alert.key));
      unseen.forEach((alert) => {
        state.seen.add(alert.key);
        notifyAlert(alert);
      });
      if (unseen.length > 0) saveStoredState();
    }

    scheduleNext(NORMAL_INTERVAL_MS);
  } catch (error) {
    state.failures += 1;
    const delay = retryIntervalMs(state.failures);
    const minutes = Math.round(delay / 60_000);
    refs.lastChecked.textContent = formatCheckedTime();
    refs.retryState.textContent = `${minutes} 分钟后重试`;
    setSourceState("连接失败", "error");
    setError(`${error.message || "未知错误"} · ${minutes} 分钟后自动重试`);
    scheduleNext(delay);
  } finally {
    state.polling = false;
    refs.checkNow.disabled = false;
    refs.checkNow.textContent = "立即检查";
  }
}

function bind() {
  readStoredState();
  updateNotificationButton();
  refs.checkNow.addEventListener("click", () => poll());
  refs.enableNotifications.addEventListener("click", requestNotifications);
  refs.alertMode.addEventListener("change", () => {
    state.mode = refs.alertMode.value === "confirmedOnly" ? "confirmedOnly" : "possibleAndConfirmed";
    saveStoredState();
    renderAlerts();
  });
  poll();

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  }
}

bind();
