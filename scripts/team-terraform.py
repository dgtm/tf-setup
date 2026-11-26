#!/usr/bin/env python3
"""Run Terraform with the selected team's configuration and isolated local state."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

from validate_config import ConfigError, validate_config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("team", help="Terraform root name, such as platform, alpha, or beta")
    parser.add_argument(
        "operation", choices=("init", "validate", "plan", "apply", "output")
    )
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z][a-z0-9_-]*", args.team):
        parser.error("team must contain lowercase letters, numbers, underscores, or hyphens and start with a letter")

    repo_dir = Path(__file__).resolve().parent.parent
    if args.team != "platform" and not (repo_dir / "configuration" / f"{args.team}.yml").is_file():
        parser.error(f"missing configuration: configuration/{args.team}.yml")

    team_dir = repo_dir / "teams" / args.team
    if not (team_dir / "main.tf").is_file():
        parser.error(f"missing Terraform root: teams/{args.team}/main.tf")

    try:
        validate_config(repo_dir, args.team)
    except ConfigError as error:
        parser.error(str(error))

    terraform = shutil.which("terraform")
    if terraform is None:
        parser.error("terraform executable was not found on PATH")

    data_dir = repo_dir / ".terraform-teams" / args.team
    state_dir = repo_dir / "state" / args.team
    data_dir.mkdir(parents=True, exist_ok=True)
    state_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["TF_DATA_DIR"] = str(data_dir)
    env["TF_WORKSPACE"] = "default"

    command = [terraform, f"-chdir={team_dir}"]
    result = subprocess.run(
        command
        + [
            "init",
            "-input=false",
            f"-backend-config=path={state_dir / 'terraform.tfstate'}",
            f"-backend-config=workspace_dir={state_dir / 'workspaces'}",
        ],
        env=env,
    )
    if result.returncode != 0 or args.operation == "init":
        return result.returncode

    return subprocess.run(command + [args.operation], env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
