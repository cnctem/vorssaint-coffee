#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Cleanly removes the streamlined Vorssaint and the system state it created:
# the login item, the closed-lid sleep override and its password-free sudoers
# rule, TCC permissions, preferences, saved state and the app's data folder.
set -uo pipefail

BUNDLE="com.vorssaint.utils"
APP="/Applications/Vorssaint.app"
LEGACY_APP="/Applications/Vorssaint Utils.app"
CLAMSHELL_RULES=(
    /etc/sudoers.d/vorssaint-clamshell
    /etc/sudoers.d/vorssaint-clamshell
    /etc/sudoers.d/vorssaint-utils-clamshell
    /etc/sudoers.d/vorss-clamshell
)

echo "▸ Quitting…"
pkill -x Vorssaint 2>/dev/null || true
pkill -x Vorssaint 2>/dev/null || true
pkill -x VorssaintUtils 2>/dev/null || true
sleep 0.5

if [[ "$(defaults read "$BUNDLE" vorssDisabledSleep 2>/dev/null)" == "1" ]]; then
    echo "▸ Restoring normal sleep (the administrator password may be asked)…"
    /usr/bin/osascript -e 'do shell script "/usr/bin/pmset disablesleep 0" with administrator privileges' \
        >/dev/null 2>&1 || echo "  ⚠ Could not restore sleep; run: sudo pmset disablesleep 0"
fi

if [[ -n "$(print -l ${CLAMSHELL_RULES[@]}(N) 2>/dev/null)" ]]; then
    echo "▸ Removing the password-free closed-lid rule…"
    /usr/bin/osascript -e \
        "do shell script \"rm -f ${(j: :)CLAMSHELL_RULES}\" with administrator privileges" \
        >/dev/null 2>&1 || echo "  ⚠ Could not remove the rule under /etc/sudoers.d"
fi

echo "▸ Resetting permissions (Accessibility)…"
tccutil reset All "$BUNDLE" >/dev/null 2>&1 || true

echo "▸ Removing the app, preferences, saved state and stored data…"
rm -rf "$APP" "$LEGACY_APP"
defaults delete "$BUNDLE" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/$BUNDLE.plist"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE.savedState"
rm -rf "$HOME/Library/Application Support/$BUNDLE"
rm -rf "$HOME/Library/Caches/$BUNDLE"
rm -rf "$HOME/Library/HTTPStorages/$BUNDLE" "$HOME/Library/HTTPStorages/$BUNDLE.binarycookies"
# The (N) qualifier is load-bearing: without it zsh aborts on an unmatched
# pattern, the ordinary case, and prints an error over a successful uninstall.
rm -f "$HOME/Library/Preferences/ByHost/$BUNDLE".*.plist(N)

echo "✓ Vorssaint removed."
