.PHONY: help install config-validate fmt fmt-check test \
	s3-module-test team-init team-validate team-plan team-apply team-output

PYTHON ?= python3
TEAM ?=

help:
	@echo "Targets:"
	@echo "  install                 Install Python validator dependencies"
	@echo "  config-validate [TEAM]  Validate team YAML and registry (platform checks registry only)"
	@echo "  fmt                    Format Terraform files"
	@echo "  fmt-check              Check Terraform formatting"
	@echo "  test                   Run team configuration validator tests"
	@echo "  s3-module-test         Run the S3 module Terraform validation test (Terraform >= 1.7)"
	@echo "  team-init TEAM=name    Initialize one Terraform root"
	@echo "  team-validate TEAM=name Run terraform validate for one root"
	@echo "  team-plan TEAM=name    Plan one Terraform root"
	@echo "  team-apply TEAM=name   Apply one Terraform root"
	@echo "  team-output TEAM=name  Show outputs for one Terraform root"

install:
	$(PYTHON) -m pip install -r requirements.txt

config-validate:
	@if [ -n "$(TEAM)" ]; then \
		$(PYTHON) scripts/validate_config.py "$(TEAM)"; \
	else \
		$(PYTHON) scripts/validate_config.py; \
	fi

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

test:
	$(PYTHON) -B -m unittest discover -s tests -p 'test_config_validation.py' -v

s3-module-test:
	terraform -chdir=modules/s3-bucket init -backend=false -input=false
	terraform -chdir=modules/s3-bucket test

team-%:
	@if [ -z "$(TEAM)" ]; then \
		echo "Set TEAM=alpha, beta, or platform" >&2; \
		exit 2; \
	fi
	$(PYTHON) scripts/team-terraform.py "$(TEAM)" "$*"
