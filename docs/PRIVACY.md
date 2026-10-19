# Privacy

Vorssaint Coffee is local-first, and the streamlined build is local-only.

## The short version

- **No account.** There is nothing to sign up for and nobody to log in as.
- **No subscription.** The app is free and stays free.
- **No telemetry.** No usage stats, crash reports or device identifiers.
- **No analytics or tracking.** No analytics kits, ad networks or third-party
  SDKs.
- **No network traffic.** This build makes no outbound connections at all.

## What the app reads

| Reading | Why |
|---|---|
| IOKit power sources | The battery percentage that drives battery protection. |
| IOKit root domain | Whether the lid is closed, and the power-assertion list closed-lid mode checks before forcing sleep. |
| `CGGetOnlineDisplayList` | Which display is the built-in panel, so closed-lid dimming touches only that one. |
| Running applications | Only when an app-based automation condition were configured; the streamlined panel offers display and power conditions. |
| `pmset -g` | An internal recovery check for a sleep override left by a crash. |

Nothing is uploaded, and nothing is shared with anyone.

## What the app writes

- User preferences for the options you set.
- The internal markers that let a crash be repaired on the next launch
  (`vorssDisabledSleep`, `vorssDimmedDisplaySavedBrightness`).
- Only after you switch on closed-lid mode, a restricted rule under
  `/etc/sudoers.d`.

## Notifications

Vorssaint Coffee posts a local notification when a timed session ends and when battery
protection stops one. They are created and delivered by macOS on this Mac.
