# X realtime stream worker

This optional worker is the server-side bridge for the official X Filtered Stream API. It keeps the Bearer Token off the web, macOS, and Windows clients.

The worker owns one rule:

```text
from:thsottiaux -is:retweet
```

That rule includes Tibo-authored posts, replies, and quote-posts while excluding native retweets. The worker also bootstraps the latest user timeline on startup, then maintains a persistent stream with reconnect backoff.

## Run locally

Create an X Developer Project/App and export its App Bearer Token. Never commit the token or put it in a client bundle.

```sh
export X_BEARER_TOKEN='…'
npm run stream:start
```

The worker binds to `127.0.0.1` by default. For a deployed worker, set `HOST=0.0.0.0` behind a TLS reverse proxy and expose only the read-only endpoints below; the X Bearer Token stays in the worker environment.

Endpoints:

- `GET http://127.0.0.1:8787/health` — connection and error state
- `GET http://127.0.0.1:8787/api/feed` — normalized feed consumed by the clients
- `GET http://127.0.0.1:8787/events` — optional server-sent event stream

To point the browser PWA at this worker, edit `web/config.js` to use `http://127.0.0.1:8787/api/feed`. macOS can use the same endpoint through its standard user defaults, while Windows uses the browser config:

```sh
defaults write local.tibo-reset-notifier feedEndpoint https://your-worker.example.com/api/feed
```

Delete that key to return macOS to the public fallback:

```sh
defaults delete local.tibo-reset-notifier feedEndpoint
```
