---
name: Bug report
about: Something isn't working as expected
labels: bug
---

**Describe the bug**
A clear description of what went wrong.

**To reproduce**
Steps to reproduce the behavior:
1.
2.

**Expected behavior**
What you expected to happen.

**Environment**
- macOS version:
- Focus Radio version:
- Station that misbehaves (if applicable):

**Logs**
If a station never starts or drops out, run from the terminal and paste the tail of
the output:

```
./build/FocusRadio.app/Contents/MacOS/FocusRadio 2>&1 | tee radio.log
```

The interesting lines are `CONNECT`, `status=`, `acclog`, `WATCHDOG`, `FALLBACK`, `PLAYING`.
