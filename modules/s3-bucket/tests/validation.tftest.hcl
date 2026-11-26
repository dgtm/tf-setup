mock_provider "aws" {}

run "rejects_non_boolean_public" {
  command = plan

  variables {
    config_file = "tests/fixtures/non_boolean_public.yml"
  }

  expect_failures = [var.config_file]
}

run "rejects_missing_public" {
  command = plan

  variables {
    config_file = "tests/fixtures/missing-public.yml"
  }

  expect_failures = [var.config_file]
}
