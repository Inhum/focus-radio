# Contributing to Focus Radio

Thanks for your interest! Focus Radio is a spare-time project, so please keep expectations
realistic: responses may be slow, and not every feature request will be accepted. That
said, bug reports and focused pull requests are very welcome.

## Reporting bugs & requesting features

Open an [issue](https://github.com/Inhum/focus-radio/issues) using the templates. For bugs,
include your macOS version, Focus Radio version, and steps to reproduce. If a station never
starts playing, attach the terminal output from a foreground run
(`./build/FocusRadio.app/Contents/MacOS/FocusRadio 2>&1 | tee radio.log`).

## Development

Requirements: macOS 13+ and Command Line Tools (`xcode-select --install`). Full Xcode is
not needed — the app is a single Swift file built directly with `swiftc`.

```bash
git clone https://github.com/Inhum/focus-radio.git
cd focus-radio
./scripts/run.sh          # build + run with logs in the terminal
```

Before opening a PR, make sure the self-test passes:

```bash
./scripts/test.sh         # builds and runs --test-all across every station
```

Note that the self-test hits real Icecast servers over the network — occasional flakes
happen; a station that fails once may pass on the next run.

## Code style

- The whole app lives in `radio.swift`. Keep it there unless there's a good reason to
  split — one file is a feature, not a debt to pay down.
- Match the surrounding code: same naming, comment density, and AppKit / AVFoundation
  idioms. Existing comments are in Russian; you're welcome to write new ones in English
  or Russian — don't mass-translate the old ones.
- Zero third-party dependencies. Only system frameworks (AppKit, AVFoundation, Foundation).
- Before touching non-trivial architecture, read [CLAUDE.md](CLAUDE.md) — it documents
  the pitfalls (real-playback detection, RunLoop modes, PLS race) that are easy to break
  on cleanup.

## Pull requests

- Keep PRs focused; one concern per PR.
- Describe what changed and how you tested it.
- For any change to playback / fallback logic, run `./scripts/test.sh` and paste the
  final score (`N/14 PASS`) in the PR description.
