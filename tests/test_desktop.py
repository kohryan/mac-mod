import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("desktop", Path(__file__).resolve().parents[1] / "scripts/desktop.py")
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


class DesktopTest(unittest.TestCase):
    def test_native_migration_and_restore_preserve_original_dock(self):
        prefs = {"autohide": "0", "tilesize": "26", "orientation": "left"}
        calls = []

        def fake_run(args, **kwargs):
            calls.append(tuple(args))
            if args[0] == "defaults":
                operation, key = args[1], args[3]
                if operation == "read":
                    return subprocess.CompletedProcess(args, 0 if key in prefs else 1, prefs.get(key, ""), "")
                if operation == "delete":
                    prefs.pop(key, None)
                else:
                    prefs[key] = {"true": "1", "false": "0"}.get(args[5], args[5])
            return subprocess.CompletedProcess(args, 0, "", "")

        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            app = home / "MacMod.app"
            executable = app / "Contents/MacOS/MacMod"
            executable.parent.mkdir(parents=True)
            executable.touch()
            legacy = home / "Library/Application Support/Übersicht/widgets/mac-mod.widget"
            legacy.parent.mkdir(parents=True)
            legacy.symlink_to(desktop.ROOT / "config/uebersicht/mac-mod.widget")
            with patch.object(desktop, "APP", app), patch.object(desktop.subprocess, "run", side_effect=fake_run):
                desktop.apply(home)
                self.assertFalse(legacy.is_symlink())
                self.assertEqual(prefs["autohide"], "0")
                self.assertEqual(prefs["orientation"], "bottom")
                desktop.apply(home)
                marker = home / "Library/Application Support/mac-mod/wallpaper-applied"
                marker.touch()
                desktop.restore(home)
                self.assertEqual(prefs, {"autohide": "0", "tilesize": "26", "orientation": "left"})
                self.assertFalse(marker.exists())
                self.assertIn((str(executable), "--restore-wallpaper"), calls)
                self.assertIn((str(executable), "--quit"), calls)
                self.assertIn((str(executable), "--disable-login"), calls)


if __name__ == "__main__":
    unittest.main()
