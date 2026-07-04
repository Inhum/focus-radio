# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-07-05

### Added
- Bilingual UI (English / Russian), chosen automatically by the system language.
- Station health indicator — a colored dot next to the status line: green (playing),
  yellow (connecting), red (unreachable).
- Update check against the GitHub Releases API from the About window (notify-only; you
  download and install updates yourself).

### Changed
- Station lineup is now **13 SomaFM channels + Nightwave Plaza** (all verified to actually
  stream). New channels: Space Station Soma, Sonic Universe, The Trip, Fluid, Secret Agent,
  Lush, and Nightwave Plaza.
- About is now a custom window (app icon, version, tagline, GitHub + Check for Updates
  buttons) instead of the standard macOS panel.
- Builds are signed with a stable self-signed certificate when available, falling back to
  ad-hoc so third-party builds still work.

### Removed
- Radio Paradise and NTS Mixtapes. Their CDNs accept the connection but don't deliver audio
  to AVPlayer from some regions (the stream stays silent), so they were replaced with
  stations confirmed to play.

### Fixed
- Real-playback detector no longer treats a static start buffer as playback, so a station
  that connects but never streams is correctly shown as failed instead of falsely "playing".

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
- App icon (concentric circles on a warm orange gradient), generated via CoreGraphics
  (`scripts/make-icon.sh`).

### Known limitations
- Some CDN-fronted stations (Radio Paradise Global, NTS Mixtapes) are geo-blocked or
  serve a redirect from certain regions; the app cycles through fallbacks but cannot
  always recover.
