<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/readme/logo-dark.svg">
    <img src="docs/assets/readme/logo.svg" width="220" alt="Vorssaint Coffee logo">
  </picture>
</p>

<h1 align="center">Vorssaint Coffee</h1>

<p align="center">
  A focused menu bar app that keeps your Mac awake, and nothing else.
</p>

<p align="center">
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="docs/PRIVACY.md">Privacy</a> ·
  <a href="docs/PERMISSIONS.md">Permissions</a> ·
  <a href="docs/TROUBLESHOOTING.md">Troubleshooting</a> ·
  <a href="LICENSE">License</a> ·
  <a href="mailto:hello@vorssaint.com">Contact</a>
</p>

This build is the streamlined edition of the Vorssaint utilities: everything
that is not part of Keep Awake is gone. The whole app is a single menu bar
icon, one panel, one Settings window and the IOKit power assertions that keep a
Mac awake.

## What it does

- **Keep the Mac awake** for a preset (15m, 30m, 1h, 2h, 4h, 8h) or
  indefinitely, or until a time you pick.
- **A countdown** next to the menu bar icon, and a live status in the panel.
- **Battery protection** ends a session when the charge drops below the level
  you choose.
- **Closed-lid mode** keeps the Mac running with the lid shut, optionally
  dimming the built-in display while it is closed. It asks for the
  administrator password once and then toggles without one.
- **Automation**: start when an external display is attached, when the Mac is
  on power, or both; optionally pause while the screen is locked.
- **Global shortcut** to toggle a session from any app, no extra permission
  required.
- **Optional pointer jiggle** during a session, for the few tools that watch
  pointer activity. This is the only option that needs Accessibility.
- **Launch at login**, a right-click toggle, and a choice of menu bar glyph and
  color.

## What was removed

The mixer, system monitor, switcher, window layout, Dock previews, clipboard
history, text snippets, shelf, uninstaller, cleaner, Homebrew tools, screenshots,
screen recorder, media tools, Dynamic Island, fan control, app updates,
onboarding and the feature hub are gone, along with their background services,
permissions, bundled media and localized strings. What remains is the Keep Awake
code path and the small shell it needs.

## Install

Download the latest disk image from the [releases page](../../releases), open
it and drag Vorssaint Coffee into Applications. The build is ad-hoc signed and
not notarized, so the first launch needs confirmation in System Settings →
Privacy & Security → Open Anyway.

## Build

The build needs macOS 14 or newer, Apple Silicon and Xcode or the Command Line
Tools.

```sh
./build.sh            # build, stage and sign build/stage/Vorssaint Coffee.app
./build.sh --dev      # a "Vorssaint Coffee (Developer)" variant with its own identity
./build.sh --install  # install into /Applications
./build.sh --test     # run the unit suite
./build/VorssaintCoffee --selftest   # dependency-free checks of the core decisions
```

`--dev` keeps its own bundle identifier (`com.vorssaint.coffee.dev`) and
preferences, so it can run beside the official app while you work on it.

## Privacy

There is no account, no telemetry and no network traffic. Everything the app
does happens on the Mac. See [docs/PRIVACY.md](docs/PRIVACY.md).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
