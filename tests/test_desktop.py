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
    def test_apply_restore_preserves_original_preferences(self):
        prefs = {"autohide": "0", "tilesize": "26"}

        def fake_run(args, **kwargs):
            if args[0] == "defaults":
                operation, key = args[1], args[3]
                if operation == "read":
                    return subprocess.CompletedProcess(args, 0 if key in prefs else 1, prefs.get(key, ""), "")
                if operation == "delete":
                    prefs.pop(key, None)
                else:
                    prefs[key] = {"true": "1", "false": "0"}.get(args[5], args[5])
            return subprocess.CompletedProcess(args, 0, "", "")

        with tempfile.TemporaryDirectory() as directory, patch.object(desktop.subprocess, "run", side_effect=fake_run):
            home = Path(directory)
            app = home / "Übersicht.app"
            app.mkdir()
            with patch.object(desktop, "UBERSICHT_APP", app):
                desktop.apply(home)
            target = home / "Library/Application Support/Übersicht/widgets/mac-mod.widget"
            self.assertTrue(target.is_symlink())
            self.assertEqual(prefs["autohide"], "1")
            self.assertEqual(prefs["tilesize"], "36")
            desktop.apply(home)
            desktop.restore(home)
            self.assertFalse(target.exists())
            self.assertEqual(prefs, {"autohide": "0", "tilesize": "26"})


if __name__ == "__main__":
    unittest.main()
