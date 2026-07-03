# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.1.0] — 2026-07-03

First public release.

### Added
- Menu-bar app with an animated equalizer icon and a popover UI (station picker,
  play/pause, volume slider).
- 14 curated stations across three providers: **SomaFM** (7 channels), **Radio Paradise**
  (Mellow, Main, Global), **NTS Mixtapes** (Slow Focus, Low Key, Sheet Music, Expansions).
- SomaFM playlists refreshed on launch via `.pls` (best available mirror per station).
- Multi-layer fallback per station: current URL → per-URL watchdog → next URL in the list
  → hardcoded snapshot → whole-station retry.
- Real-playback detector (buffer/bytes/currentTime) instead of relying on
  `timeControlStatus == .playing` alone.
- Popover auto-closes on click outside the app (global `NSEvent` monitor).
- `--test-all` self-test that iterates all stations and exits non-zero if any fail;
  `--test-one <idx>` for verbose single-station diagnostics.
- App icon (equalizer bars on a warm gradient), generated via CoreGraphics
  (`scripts/make-icon.sh`).

### Known limitations
- Some CDN-fronted stations (Radio Paradise Global, NTS Mixtapes) are geo-blocked or
  serve a redirect from certain regions; the app cycles through fallbacks but cannot
  always recover.
