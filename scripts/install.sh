#!/bin/bash
set -euo pipefail
mac_mod_root="$(cd "$(dirname "$0")/.." && pwd)"
mac_mod_destination="$HOME/Applications/MacMod.app"
if [[ -e "$mac_mod_destination" ]]; then
  mac_mod_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$mac_mod_destination/Contents/Info.plist")"
  if [[ "$mac_mod_identifier" != "local.kohryan.mac-mod" ]]; then
    printf 'Refusing to overwrite another application: %s\n' "$mac_mod_destination" >&2
    exit 1
  fi
fi
bash "$mac_mod_root/scripts/build.sh"
mkdir -p "$HOME/Applications"
ditto "$mac_mod_root/output/MacMod.app" "$mac_mod_destination"
python3 "$mac_mod_root/scripts/desktop.py" apply
printf 'Installed: %s\n' "$mac_mod_destination"
