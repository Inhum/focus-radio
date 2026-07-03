# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead, use GitHub's private
[security advisories](https://github.com/Inhum/focus-radio/security/advisories/new) to report
privately, or contact the maintainer ([@Inhum](https://github.com/Inhum)).

You'll get a response as soon as reasonably possible (this is a spare-time project).

## How Focus Radio handles your data

Focus Radio is a plain audio streamer. It stores no user data, requires no account, and has
no backend of its own.

- **No telemetry, no analytics, no crash reporting.**
- **No credentials, keys, or personal data** are stored or transmitted.
- Settings kept locally in `~/Library/Preferences/com.ushakov.focus-radio.plist`
  (currently: last selected station and volume).

## Network activity

The app only talks to servers that publish the streams:

- **`api.somafm.com`** — HTTPS `GET` for `.pls` playlist files (SomaFM stations only), to
  pick up current stream URLs on launch.
- **Station stream endpoints** listed in `stations` inside `radio.swift` — e.g.
  `ice*.somafm.com`, `stream.radioparadise.com`, `stream-mixtape-geo.ntslive.net`. Each is
  a straight audio stream over HTTPS/HTTP; no headers other than default `User-Agent` are
  sent.

No other network calls are made. Adding or removing a station only touches the `stations`
list; the app has no auto-update mechanism and pulls no code at runtime.

## Supported versions

Only the latest release receives fixes.
