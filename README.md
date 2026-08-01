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

Allow notifications on the first launch. The bell menu includes **Check now**, **Open latest signal**, and **Send test notification**.

To build an app bundle:

```sh
make app
open "dist/Tibo Reset Notifier.app"
```

The generated app is locally ad-hoc signed, but not notarized with a Developer ID. You can add it to macOS Login Items after verifying that it works for you.

## Data source and limitations

The current source is the independent public endpoint at <https://codex-reset.com/api/feed>, not an OpenAI or X API. If that feed is stale, unavailable, or wrong, the app does not invent an alert. Treat the original X post and your Codex client as the source of truth.

This project is independent and is not affiliated with OpenAI, X, or Thibault “Tibo” Sottiaux.

## Development

```sh
make test
make app
```

`make test` is a zero-dependency self-check that validates the public feed JSON shape, confirmed resets, future reset signals, and common false-positive exclusions.

## Roadmap

- [x] Native macOS menu-bar notifier
- [x] Feed parsing, conservative reset classification, and local deduplication
- [ ] Cross-platform desktop client
- [ ] Optional official X API adapter for lower-latency, independent ingestion

## License

No open-source license has been selected yet. The repository is public for review and feedback; reuse rights are not granted until a license is added.
