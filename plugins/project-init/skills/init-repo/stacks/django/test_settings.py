"""The project's settings: Django's system checks pass, and the secret key
comes from the environment."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

from django.core.management import call_command


def test_system_checks_pass() -> None:
    call_command("check")


def test_settings_refuse_to_load_without_a_secret_key(tmp_path: Path) -> None:
    # A copy of the settings, away from .env: only the environment counts.
    (tmp_path / "config").mkdir()
    shutil.copy(Path(__file__).with_name("settings.py"), tmp_path / "config")
    environment = {k: v for k, v in os.environ.items() if k != "DJANGO_SECRET_KEY"}

    result = subprocess.run(
        [sys.executable, "config/settings.py"],
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode != 0
    assert "DJANGO_SECRET_KEY" in result.stderr
