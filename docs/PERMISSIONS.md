# Permissions

The streamlined app needs no permission for its core job. Keeping a Mac awake
is an IOKit power assertion, which requires nothing from the user.

Only two optional pieces ask for anything:

| Permission | Optional | Powers |
|---|---|---|
| Accessibility | Yes | The optional "Move pointer slightly" option. It is off by default and the rest of the app is unaffected without it. |
| Administrator password | Yes, once | Closed-lid mode. It writes a `sudoers.d` rule restricted to `pmset disablesleep 0/1`, so later toggles never ask again. Declining simply leaves closed-lid mode off. |

## Accessibility (pointer jiggle)

Turn it on in System Settings under **Privacy & Security → Accessibility**, then
use the request button that appears next to the option in Settings or the panel.

To reset the grant after a rebuild:

```sh
tccutil reset Accessibility com.vorssaint.coffee
```

## Administrator password (closed-lid mode)

The first time you switch on **Keep going with the lid closed**, macOS asks for
your password to install the restricted rule at:

```
/etc/sudoers.d/vorssaint-coffee-clamshell
```

The rule only allows `/usr/bin/pmset disablesleep 1` and
`/usr/bin/pmset disablesleep 0`. Quitting the app restores normal sleep, and a
crash is repaired on the next launch.

`Tools/uninstall.sh` removes the rule and restores sleep before deleting the
app.
