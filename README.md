# Tibo Reset Watch

Independent, local-first reset alerts for public posts from `@thsottiaux`.

> **Current release:** v0.3 macOS app plus a web/PWA client, a Windows Electron target, and an optional X realtime stream worker. The macOS app and browser client are verified locally; Windows packaging and credentialed X streaming still need their platform checks.

Tibo Reset Watch polls a public reset feed every two minutes, classifies new posts, and shows a native notification for either a likely upcoming reset or a confirmed reset. The same Tibo-only contract powers the macOS app, browser PWA, and Windows shell. It does not require an X, OpenAI, or Telegram login, and it never reads a user's Codex usage.

## What it does

- Shows a small menu-bar bell instead of keeping a browser tab open.
- Accepts only canonical posts authored by `@thsottiaux`; other accounts and non-Tibo events are excluded.
- Shows Tibo's latest accepted timeline post in the menu even when it is unrelated to resets.
- Separates **possible reset signals** from **confirmed resets**.
- Silently establishes a baseline on first launch, so old posts are never replayed as alerts.
- Lets a signal alert upgrade to a second confirmation alert for the same post.
- Deduplicates locally with `UserDefaults`; no account data is uploaded.
- Retries a failed or stale feed with bounded backoff: 1, 2, 4, 8, then at most 15 minutes.
- Lets you choose between **possible + confirmed** alerts (the default) and **confirmed only** alerts.
- Opens the exact original X post when you click a reset notification or choose **打开原帖**.
- Runs as a static browser PWA with local browser notifications while the page is open.
- Uses the same browser client inside a Windows Electron shell, with NSIS and portable targets.

## Detection policy

| Result | Rule |
| --- | --- |
| Confirmed reset | The feed marks the post `confirmed`, or the text explicitly says usage limits were reset. |
| Possible reset | The post includes reset + Codex/usage context + a future cue such as “in a few hours” or “tomorrow.” |
| Ignore | A clear “no reset,” a joke, or an isolated reference to `reset`. |

The tool is intentionally conservative: it would rather miss ambiguous chatter than send a noisy alert.

## Install and run

Requirements: macOS 13+, Apple Swift 6, and Make.

```sh
git clone https://github.com/Chloride233/tibo-reset-watch.git
cd tibo-reset-watch
make run
```

Allow notifications on the first launch. The bell menu shows the latest Tibo post and its source time, lets you choose an alert condition, and includes **立即检查** and **发送测试通知**. Click **打开最新动态** to open the exact X post. Changing the alert condition only affects future posts; old suppressed signals are not replayed later.

To build and install a daily-use app bundle into `~/Applications`:

```sh
make install
```

This closes and replaces only `~/Applications/Tibo Reset Watch.app`, locally re-signs it, and launches it. It does not add a Login Item automatically. The app is ad-hoc signed rather than notarized with a Developer ID, so only install the bundle you built from source after reviewing it.

For a build artifact without installing it:

```sh
make app
open "dist/Tibo Reset Watch.app"
```

### Web / PWA

The browser client has no build step and reads the public feed directly. For local development:

```sh
make web
open http://localhost:8080
```

It can be hosted as a static site (including GitHub Pages). Browser notifications are optional and only fire while the page is open. The page keeps its alert deduplication and alert-mode preference in local storage.

To use an official X realtime source, run the optional server-side worker described in [`server/README.md`](server/README.md). It owns the Bearer Token, listens for `from:thsottiaux -is:retweet`, bootstraps the latest timeline, and exposes the same normalized `/api/feed` contract. Point `web/config.js` at that endpoint for the browser/Windows client; point macOS at it with `defaults write local.tibo-reset-notifier feedEndpoint https://your-worker.example.com/api/feed`. The clients never receive the Bearer Token.

### Windows

The Windows target is an Electron wrapper around the same `web/` client. On a machine with Node.js and npm:

```sh
npm install
npm start
npm run windows:build
```

`npm run windows:build` produces NSIS and portable artifacts in `dist-windows/`. The repository contains the target configuration, but this macOS workspace has not yet executed a Windows installer or Windows runtime smoke test.

## Data source and limitations

The current source is the independent public endpoint at <https://codex-reset.com/api/feed>, not an OpenAI or X API. The app requires the payload to identify itself as the `thsottiaux` timeline, then accepts only canonical URLs shaped like `x.com/thsottiaux/status/<same-id>`. Tibo's replies and quote-posts qualify when he authored their canonical status URL; posts authored by OpenAI, OpenAI Status, or community accounts do not.

The upstream service says it syncs about every 15 minutes, so this is not a real-time X stream. If the feed is stale, unavailable, or fails the author checks, the app does not invent an alert. Treat the original X post and your Codex client as the source of truth.

This project is independent and is not affiliated with OpenAI, X, or Thibault “Tibo” Sottiaux.

## Development

```sh
make test
make app
npm run web:check
npm run stream:check
```

`make test` is a zero-dependency macOS/core self-check that validates the Tibo timeline identity, canonical post authorship, public feed JSON shape, reset classification, false-positive exclusions, and retry-backoff limits. `npm run web:check` checks the browser and Electron JavaScript syntax. `npm run stream:check` checks the optional Node worker syntax without contacting X.

GitHub Actions runs the macOS self-check, browser/worker checks, and a Windows installer build on every push and pull request.

## Roadmap

- [x] Native macOS menu-bar notifier
- [x] Tibo-only author validation, conservative reset classification, and local deduplication
- [x] Bounded retry backoff, notification deep links, alert preferences, and a local installer
- [x] Browser/PWA client with the same Tibo-only feed contract
- [x] Windows Electron shell and NSIS/portable packaging configuration
- [x] Optional server-side X Filtered Stream worker with a normalized feed endpoint
- [ ] Windows installer/runtime validation on Windows CI or a Windows machine
- [ ] Credentialed X stream integration and deployment validation
- [ ] Optional official X API adapter for lower-latency, independent ingestion

## License

No open-source license has been selected yet. The repository is public for review and feedback; reuse rights are not granted until a license is added.
