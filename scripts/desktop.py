#!/usr/bin/env python3
"""Install the local cockpit widget and keep a small, reversible Dock backup."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
UBERSICHT_APP = Path("/Applications/Übersicht.app")
DOCK = {"autohide": ("-bool", True), "show-recents": ("-bool", False), "tilesize": ("-int", 36)}


def run(*args):
    return subprocess.run(args, text=True, capture_output=True, check=True)


def write_dock(key, kind, value):
    run("defaults", "write", "com.apple.dock", key, kind, str(value).lower())


def apply(home):
    source = ROOT / "config/uebersicht/mac-mod.widget"
    target = home / "Library/Application Support/Übersicht/widgets/mac-mod.widget"
    state_file = home / "Library/Application Support/mac-mod/state.json"
    if target.is_symlink() and target.resolve() == source and state_file.exists():
        print("mac-mod sudah terpasang. Konfigurasi widget mengikuti isi repo.")
        return
    if target.exists() or target.is_symlink() or state_file.exists():
        raise RuntimeError("Widget atau backup sudah ada. Jalankan restore sebelum apply ulang.")
    if not UBERSICHT_APP.exists():
        raise RuntimeError("Install Übersicht terlebih dahulu: brew install --cask ubersicht")

    original = {}
    for key, (kind, _) in DOCK.items():
        result = subprocess.run(["defaults", "read", "com.apple.dock", key], text=True, capture_output=True)
        original[key] = None if result.returncode else (bool(int(result.stdout.strip())) if kind == "-bool" else int(result.stdout.strip()))
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps({"source": str(source), "dock": original}, indent=2) + "\n")
    os.chmod(state_file, 0o600)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(source, target_is_directory=True)
    for key, (kind, value) in DOCK.items():
        write_dock(key, kind, value)
    subprocess.run(["killall", "Dock"], capture_output=True)
    print(f"Widget terpasang: {target}\nBackup Dock: {state_file}\nBuka Übersicht untuk menampilkan tema.")


def restore(home):
    state_file = home / "Library/Application Support/mac-mod/state.json"
    target = home / "Library/Application Support/Übersicht/widgets/mac-mod.widget"
    if not state_file.exists():
        raise RuntimeError("Tidak ada backup mac-mod yang aktif.")
    state = json.loads(state_file.read_text())
    if target.is_symlink() and str(target.resolve()) == state["source"]:
        target.unlink()
    elif target.exists() or target.is_symlink():
        raise RuntimeError("Widget telah diganti di luar mac-mod; tidak dihapus otomatis.")
    for key, (kind, _) in DOCK.items():
        value = state["dock"][key]
        if value is None:
            existing = subprocess.run(["defaults", "read", "com.apple.dock", key], capture_output=True)
            if existing.returncode == 0:
                run("defaults", "delete", "com.apple.dock", key)
        else:
            write_dock(key, kind, value)
    subprocess.run(["killall", "Dock"], capture_output=True)
    state_file.replace(state_file.with_name("last-restored.json"))
    print("Widget dilepas dan pengaturan Dock dikembalikan. Übersicht tetap terpasang.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("apply", "restore"))
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.exit(1, "mac-mod memerlukan macOS.\n")
    try:
        {"apply": apply, "restore": restore}[args.action](Path.home())
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"mac-mod: {error}\n")
