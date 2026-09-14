"""Run the shell tests in Docker from Windows, Linux or macOS (Python 3)."""

import argparse
from pathlib import Path
import subprocess
import sys


def main():
    """Run the tests in a disposable container and return Docker's exit code."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--image", default="fansly-scraper", help="Docker image to test"
    )
    args = parser.parse_args()
    tests_path = Path(__file__).resolve().parent

    # Only test code is mounted; /config and /data are disposable container data.
    command = [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        "--volume",
        f"{tests_path}:/tests:ro",
        "--entrypoint",
        "sh",
        args.image,
        "/tests/entrypoint-errors.sh",
    ]
    try:
        return subprocess.call(command)
    except FileNotFoundError:
        print(
            "Docker was not found. Install Docker and make it available in PATH.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
