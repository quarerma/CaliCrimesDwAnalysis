#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DBT_DIR = ROOT / "dbt"


def build_command() -> list[str]:
    if shutil.which("dbt"):
        return ["dbt", "build", "--profiles-dir", "."]

    if shutil.which("python"):
        return [sys.executable, "-m", "dbt", "build", "--profiles-dir", "."]

    raise SystemExit("dbt was not found on PATH and no Python interpreter could be used to invoke it.")


def main() -> int:
    if not DBT_DIR.exists():
        raise SystemExit(f"dbt directory not found: {DBT_DIR}")

    command = build_command() + sys.argv[1:]
    print(f"Running: {' '.join(command)}")
    print(f"Working directory: {DBT_DIR}")

    completed = subprocess.run(command, cwd=DBT_DIR, env=os.environ.copy())
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
