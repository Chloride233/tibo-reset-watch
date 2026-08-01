# Tibo Reset Watch

Independent, local-first reset alerts for public posts from `@thsottiaux`.

> **Current release:** macOS 13+ menu-bar app. Windows and Linux support are planned, not implemented.

Tibo Reset Watch polls a public reset feed every two minutes, classifies new posts, and shows a native macOS notification for either a likely upcoming reset or a confirmed reset. It does not require an X, OpenAI, or Telegram login, and it never reads a user's Codex usage.

## What it does

- Shows a small menu-bar bell instead of keeping a browser tab open.
- Separates **possible reset signals** from **confirmed resets**.
- Silently establishes a baseline on first launch, so old posts are never replayed as alerts.
- Lets a signal alert upgrade to a second confirmation alert for the same post.
- Deduplicates locally with `UserDefaults`; no account data is uploaded.
- Retries a failed or stale feed with bounded backoff: 1, 2, 4, 8, then at most 15 minutes.
- Lets you choose between **possible + confirmed** alerts (the default) and **confirmed only** alerts.
- Opens the exact original X post when you click a reset notification or choose **打开原帖**.

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

Allow notifications on the first launch. The bell menu shows the current source health, lets you choose an alert condition, and includes **立即检查**, **打开最新**, and **发送测试通知**. Changing the alert condition only affects future posts; old suppressed signals are not replayed later.

To build and install a daily-use app bundle into `~/Applications`:

```sh
make install
```

This replaces only `~/Applications/Tibo Reset Watch.app`, locally re-signs it, and launches it. It does not add a Login Item automatically. The app is ad-hoc signed rather than notarized with a Developer ID, so only install the bundle you built from source after reviewing it.

For a build artifact without installing it:

```sh
make app
open "dist/Tibo Reset Watch.app"
```

## Data source and limitations

The current source is the independent public endpoint at <https://codex-reset.com/api/feed>, not an OpenAI or X API. If that feed is stale, unavailable, or wrong, the app does not invent an alert. Treat the original X post and your Codex client as the source of truth.

This project is independent and is not affiliated with OpenAI, X, or Thibault “Tibo” Sottiaux.

## Development

```sh
make test
make app
```

`make test` is a zero-dependency self-check that validates the public feed JSON shape, confirmed resets, future reset signals, common false-positive exclusions, and retry-backoff limits.

## Roadmap

- [x] Native macOS menu-bar notifier
- [x] Feed parsing, conservative reset classification, and local deduplication
- [x] Bounded retry backoff, notification deep links, alert preferences, and a local installer
- [ ] Cross-platform desktop client
- [ ] Optional official X API adapter for lower-latency, independent ingestion

## License

No open-source license has been selected yet. The repository is public for review and feedback; reuse rights are not granted until a license is added.
