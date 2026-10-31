#!/usr/bin/env python3
"""Apply or restore the native MacMod desktop settings."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
APP = Path.home() / "Applications/MacMod.app"
DOCK = {"autohide": ("-bool", None), "show-recents": ("-bool", None), "tilesize": ("-int", None), "orientation": ("-string", "bottom")}


def read_dock(key, kind):
    result = subprocess.run(["defaults", "read", "com.apple.dock", key], text=True, capture_output=True)
    if result.returncode:
        return None
    value = result.stdout.strip()
    return bool(int(value)) if kind == "-bool" else int(value) if kind == "-int" else value


def run(*args):
    return subprocess.run(args, text=True, capture_output=True, check=True)


def write_dock(key, kind, value):
    run("defaults", "write", "com.apple.dock", key, kind, str(value).lower())


def remove_legacy_overlay(home):
    target = home / "Library/Application Support/Übersicht/widgets/mac-mod.widget"
    if target.is_symlink() and target.resolve() == ROOT / "config/uebersicht/mac-mod.widget":
        target.unlink()


def apply(home):
    if not APP.exists():
        raise RuntimeError("Install aplikasi dahulu: bash scripts/install.sh")
    state_file = home / "Library/Application Support/mac-mod/state.json"
    if not state_file.exists():
        state = {"version": 2, "dock": {}}
    else:
        state = json.loads(state_file.read_text())
        if not isinstance(state.get("dock"), dict):
            raise RuntimeError("Backup Dock tidak valid; pengaturan tidak diubah.")
    for key, (kind, _) in DOCK.items():
        if key not in state["dock"]:
            state["dock"][key] = read_dock(key, kind)
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps(state, indent=2) + "\n")
    state_file.chmod(0o600)
    remove_legacy_overlay(home)
    for key, (kind, value) in DOCK.items():
        if value is not None:
            write_dock(key, kind, value)
    subprocess.run(["killall", "Dock"], capture_output=True)
    print(f"Pengaturan tersimpan. Buka {APP}\nBackup Dock: {state_file}")


def restore(home):
    state_file = home / "Library/Application Support/mac-mod/state.json"
    if not state_file.exists():
        raise RuntimeError("Tidak ada backup mac-mod yang aktif.")
    state = json.loads(state_file.read_text())
    if not all(key in state.get("dock", {}) for key in DOCK):
        raise RuntimeError("Backup Dock tidak valid; pengaturan tidak diubah.")
    executable = APP / "Contents/MacOS/MacMod"
    marker = state_file.parent / "wallpaper-applied"
    if marker.exists():
        if not executable.exists():
            raise RuntimeError("Build ulang aplikasi untuk mengembalikan wallpaper.")
        run(str(executable), "--restore-wallpaper")
        marker.unlink()
    if executable.exists():
        run(str(executable), "--disable-login")
        run(str(executable), "--quit")
    remove_legacy_overlay(home)
    for key, (kind, _) in DOCK.items():
        value = state["dock"][key]
        if value is None:
            if subprocess.run(["defaults", "read", "com.apple.dock", key], capture_output=True).returncode == 0:
                run("defaults", "delete", "com.apple.dock", key)
        else:
            write_dock(key, kind, value)
    subprocess.run(["killall", "Dock"], capture_output=True)
    state_file.replace(state_file.with_name("last-restored.json"))
    print("Widget ditutup, wallpaper dan Dock dikembalikan.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("apply", "restore"))
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.exit(1, "mac-mod memerlukan macOS.\n")
    try:
        {"apply": apply, "restore": restore}[args.action](Path.home())
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"mac-mod: {error}\n")
