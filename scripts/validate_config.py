#!/usr/bin/env python3
"""Validate repository YAML before running Terraform; no AWS access required."""

import argparse
import json
from pathlib import Path
import re
import sys

try:
    import yaml
except ImportError:
    raise SystemExit("Install the validator dependency: python3 -m pip install -r requirements.txt")

try:
    from jsonschema import Draft202012Validator
    from jsonschema.exceptions import SchemaError
except ImportError:
    raise SystemExit("Install the validator dependency: python3 -m pip install -r requirements.txt")


class ConfigError(ValueError):
    pass


class ConfigLoader(yaml.SafeLoader):
    pass


# Match Terraform's YAML booleans: on/off/yes/no remain strings.
ConfigLoader.yaml_implicit_resolvers = {
    key: [(tag, pattern) for tag, pattern in values if tag != "tag:yaml.org,2002:bool"]
    for key, values in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
ConfigLoader.add_implicit_resolver("tag:yaml.org,2002:bool", re.compile(r"^(true|false|True|False|TRUE|FALSE)$"), list("tTfF"))


def unique_mapping(loader, node):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=True)
        if not isinstance(key, str):
            raise ConfigError(f"line {key_node.start_mark.line + 1}: mapping keys must be strings")
        if key in result:
            raise ConfigError(f"line {key_node.start_mark.line + 1}: duplicate key {key!r}")
        result[key] = loader.construct_object(value_node, deep=True)
    return result


ConfigLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)
TEAM_ID = r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?"
ROLE_NAME = r"[A-Za-z0-9_+=,.@-]{1,64}"
OPERATOR_ARN = r"arn:[a-z][a-z0-9-]*:iam::[0-9]{12}:(?:user|role)/[A-Za-z0-9_+=,.@/-]+"
ENVIRONMENT = r"[a-z][a-z0-9_-]{0,15}"


def require(condition, location, message):
    if not condition:
        location = location.replace(".yml.", ".yml: ", 1)
        raise ConfigError(f"{location}: {message}")


def mapping(value, location, allowed, required=()):
    require(isinstance(value, dict), location, "must be a mapping")
    for key in value:
        require(key in allowed, f"{location}.{key}", "unknown setting")
    for key in required:
        require(key in value, f"{location}.{key}", "is required")
    return value


def text(value, location, pattern=None, maximum=None):
    require(isinstance(value, str) and bool(value.strip()), location, "must be a nonempty string")
    if pattern:
        require(re.fullmatch(pattern, value) is not None, location, "invalid format")
    if maximum:
        require(len(value) <= maximum, location, f"must not exceed {maximum} characters")
    return value


def tags(value, location):
    require(isinstance(value, dict), location, "must be a string-to-string mapping")
    for key, item in value.items():
        text(key, location, maximum=128)
        require(isinstance(item, str) and len(item) <= 256, f"{location}.{key}", "must be a string of at most 256 characters")


def load(path):
    location = f"configuration/{path.name}"
    try:
        return yaml.load(path.read_text(), Loader=ConfigLoader)
    except (OSError, UnicodeError, yaml.YAMLError, ConfigError) as error:
        raise ConfigError(f"{location}: {error}") from None


def validate_team_schema(config, directory, location):
    schema_path = directory / "schemas" / "team.schema.json"
    try:
        schema = json.loads(schema_path.read_text())
        Draft202012Validator.check_schema(schema)
    except (OSError, UnicodeError, json.JSONDecodeError, SchemaError) as error:
        raise ConfigError(f"{location}: could not load team schema: {error}") from None

    errors = sorted(
        Draft202012Validator(schema).iter_errors(config),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if not errors:
        return

    error = errors[0]
    path = list(error.absolute_path)
    if error.validator == "required":
        missing = next(
            (field for field in error.validator_value if f"'{field}' is a required property" in error.message),
            None,
        )
        if missing:
            path.append(missing)
    field = ".".join(str(part) for part in path) or "<root>"
    raise ConfigError(f"{location}: {field}: {error.message}")


def validate_shared(directory):
    location = "configuration/teams.yml"
    registry = mapping(load(directory / "teams.yml"), location, {"teams"}, ("teams",))["teams"]
    require(isinstance(registry, dict) and bool(registry), f"{location}.teams", "must be a nonempty mapping")
    role_names = {"platform-ci"}
    for team_id, team in registry.items():
        field = f"{location}.teams.{team_id}"
        text(team_id, field, TEAM_ID, 64)
        mapping(team, field, {"name", "role_name", "environment", "tags", "operator_arns"}, ("name", "role_name"))
        text(team["name"], f"{field}.name", maximum=256)
        role = text(team["role_name"], f"{field}.role_name", ROLE_NAME)
        require(role.lower() not in role_names, f"{field}.role_name", "must be unique, including the platform-ci role")
        role_names.add(role.lower())
        if "environment" in team:
            text(team["environment"], f"{field}.environment", ENVIRONMENT)
        tags(team.get("tags", {}), f"{field}.tags")
        operators = team.get("operator_arns", [])
        require(isinstance(operators, list), f"{field}.operator_arns", "must be a list of exact IAM user/role ARNs")
        for arn in operators:
            text(arn, f"{field}.operator_arns", OPERATOR_ARN)
    return registry


def validate_config(repo, team):
    text(team, "team", r"[a-z][a-z0-9_-]*")
    directory = Path(repo) / "configuration"
    registry = validate_shared(directory)
    if team == "platform":
        return
    location = f"configuration/{team}.yml"
    config = load(directory / f"{team}.yml")
    validate_team_schema(config, directory, location)
    team_id = config["team_id"]
    require(team_id in registry, f"{location}.team_id", "must be registered in configuration/teams.yml")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("team", nargs="?", help="Validate one team or platform; omit to validate all configurations")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    teams = [args.team] if args.team else sorted(path.stem for path in (repo / "configuration").glob("*.yml") if path.stem != "teams")
    if not teams:
        parser.error("no configuration files found")
    try:
        for team in teams:
            validate_config(repo, team)
    except ConfigError as error:
        print(error, file=sys.stderr)
        return 1
    print(f"Configuration valid: {', '.join(teams)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
