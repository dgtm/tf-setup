"""Check the most important team configuration validation behavior."""

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from validate_config import ConfigError, validate_config


class ConfigValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="config-validation-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(SCRIPTS.parent / "configuration", self.root / "configuration")
        self.valid = {
            "team_id": "team-001",
            "aws_region": "eu-central-1",
            "buckets": {"assets": {"name": "assets", "public": False}},
        }

    def write_config(self, config):
        path = self.root / "configuration" / "alpha.yml"
        path.write_text(json.dumps(config))

    def test_valid_team_config_passes_without_reading_other_teams(self):
        self.write_config(self.valid)
        (self.root / "configuration" / "beta.yml").write_text("not: [valid")

        validate_config(self.root, "alpha")

    def test_rejects_missing_fields_bad_option_types_and_unregistered_team(self):
        cases = [
            ({"aws_region": "eu-central-1", "buckets": {"assets": {"name": "assets"}}}, "team_id"),
            (
                {
                    **self.valid,
                    "buckets": {"assets": {"name": "assets", "public": "true"}},
                },
                "public",
            ),
            ({**self.valid, "team_id": "team-999"}, "team_id"),
        ]

        for config, field in cases:
            with self.subTest(field=field):
                self.write_config(config)
                with self.assertRaises(ConfigError) as error:
                    validate_config(self.root, "alpha")

                self.assertIn(field, str(error.exception))


if __name__ == "__main__":
    unittest.main()
