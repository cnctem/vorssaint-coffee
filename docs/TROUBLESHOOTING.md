# Troubleshooting

The commands below all point at Vorssaint Coffee's bundle identifier,
`com.vorssaint.coffee`.

## The menu bar icon is gone

Open Vorssaint Coffee again from Applications or Spotlight. A running copy rebuilds
the status item and pops the panel, so the icon comes back without a relaunch.
If the menu bar is simply full, macOS may have moved the icon; check
**System Settings → Control Center → Menu Bar Only**.

## The Mac still sleeps

- Check that a session is active: the icon shows the active glyph and the panel
  says either a countdown or "Active until you turn it off".
- If **Allow the display to sleep** is on, the screen turns off on its normal
  timer, but the Mac itself stays awake. That is what the option is for.
- If **Battery protection** is set and the Mac is on battery below the limit,
  a session ends immediately. Plug in or lower the limit.
- Closed-lid mode requires its rule. Open Settings and check the caption under
  **Keep going with the lid closed**; if it asks for a password, the rule is not
  installed yet.

## Closed-lid mode keeps asking for a password

The password-free rule is not in place, or a failed enable left sleep disabled.
Quit and reopen Vorssaint Coffee; launch recovery restores sleep and re-probes the
rule. To check it by hand:

```sh
sudo -n /usr/bin/pmset disablesleep 0
```

If that asks for a password, the rule is missing. Switching the option off and
on again re-installs it.

## Sleep stayed disabled after a crash

Vorssaint Coffee writes a marker before disabling sleep and clears it after restoring.
A launch with the marker still set runs recovery and asks for your password if
needed. To repair by hand:

```sh
sudo pmset disablesleep 0
defaults delete com.vorssaint.coffee vorssDisabledSleep
```

## The pointer jiggle does nothing

It needs Accessibility. Grant it in **System Settings → Privacy & Security →
Accessibility**, or use the request button beside the option. After a
code-signing change, reset the stale grant:

```sh
tccutil reset Accessibility com.vorssaint.coffee
```

## Launch at login is not working

Registering can succeed while macOS still needs approval. Check
**System Settings → General → Login Items** and allow Vorssaint Coffee. The app also
repairs a registration the system lost on the next launch.

## Remove everything

```sh
Tools/uninstall.sh
```

It quits the app, restores normal sleep, removes the `sudoers.d` rule, resets
permissions and deletes the app and its preferences.

## Reporting a bug

Include your macOS version, the Vorssaint Coffee version (About), what you did and
what happened. Email <hello@vorssaint.com>.
