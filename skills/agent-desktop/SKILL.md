---
name: agent-desktop
description: See and operate native desktop apps (macOS) through the accessibility tree with the agent-desktop CLI — for end-to-end UI checks of an app you are building (click, type, toggle, scroll, read state, capture a window). Use when you need to verify or drive a desktop app's UI; not for web pages (use Playwright) and not for measuring frame rate.
argument-hint: "[app name or what to verify]"
allowed-tools: Bash(agent-desktop status *) Bash(agent-desktop permissions *) Bash(agent-desktop skills *) Bash(agent-desktop list-apps *) Bash(agent-desktop list-windows *) Bash(agent-desktop snapshot *) Bash(agent-desktop find *) Bash(agent-desktop get *) Bash(agent-desktop is *)
---

# agent-desktop

Task (may be empty): $ARGUMENTS

The CLI ships its own documentation matched to the installed version. **Read it
before the first action** in a session, instead of relying on memory:

```bash
agent-desktop status                 # version, permissions, state
agent-desktop skills get desktop     # snapshot → act on a ref → snapshot again; retry rules
agent-desktop skills get platform    # what differs on macOS
agent-desktop <command> --help       # flags for one command
```

Rules on this machine:

1. **Permissions.** If `status`/`permissions` reports accessibility `denied`,
   stop and ask the user to grant it (System Settings → Privacy & Security →
   Accessibility → the terminal running you, e.g. iTerm). Never try to work
   around it, and never run `--guide` flows that click through settings yourself.
2. **Headless only.** Use the default ref-based actions. Never pass `--headed`
   (physical mouse/keyboard) unless the user allows it at that moment — they may
   be using the machine.
3. **Scope.** Only drive apps of the project you are working on (dev builds).
   Never operate the user's personal apps (mail, browser, messages, password
   managers, System Settings) and never read their notifications or clipboard
   unless asked.
4. **Privacy.** Snapshots and screenshots can contain private content: keep
   them out of commits, logs and uploads. Do not use the JEV helper (it sends
   screen descriptions to a model provider) unless the user asks.
5. **Verify every action** with a new snapshot; refs belong to one snapshot.
   Retry only when `error.disposition.retry` is `safe`.
6. It does not measure frame time or smoothness; use the project's in-app
   performance gates for that.
7. Close what you launched (`agent-desktop close-app`) when done.
