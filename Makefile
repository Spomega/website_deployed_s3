AWS_PROFILE ?= spomega
export AWS_PROFILE

ENV ?= dev
TF_DIR := environments/$(ENV)
PLAN_FILE := plan.tfplan
DESTROY_PLAN_FILE := destroy.tfplan
BOOTSTRAP_DIR := bootstrap
BOOTSTRAP_PLAN_FILE := bootstrap.tfplan

# Once bootstrap has been applied, this reads the state bucket from its output.
# Override it when needed: make init ENV=dev STATE_BUCKET=my-state-bucket
STATE_BUCKET ?= $(shell terraform -chdir=$(BOOTSTRAP_DIR) output -raw state_bucket_name 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: help bootstrap-init bootstrap-validate bootstrap-plan bootstrap-apply \
	check-env check-state-bucket init validate plan apply destroy-plan destroy \
	output url fmt validate-all

help:
	@printf '%s\n' \
		'Terraform website commands:' \
		'  make bootstrap-plan                 Initialize and plan the state bucket.' \
		'  make bootstrap-apply                Apply the saved bootstrap plan.' \
		'  make init ENV=dev                   Initialize one environment backend.' \
		'  make plan ENV=dev                   Validate and save an environment plan.' \
		'  make apply ENV=dev                  Apply the saved environment plan.' \
		'  make destroy-plan ENV=dev           Save a destroy plan for an environment.' \
		'  make destroy ENV=dev                Apply the saved destroy plan.' \
		'  make output ENV=dev                 Show Terraform outputs.' \
		'  make url ENV=dev                    Show the CloudFront HTTPS URL.' \
		'  make fmt                            Format all Terraform configuration.' \
		'  make validate-all                   Validate bootstrap and every environment.' \
		'' \
		'Use ENV=dev, ENV=staging, or ENV=prod. The default is dev.'

bootstrap-init:
	terraform -chdir=$(BOOTSTRAP_DIR) init -input=false

bootstrap-validate: bootstrap-init
	terraform -chdir=$(BOOTSTRAP_DIR) validate

bootstrap-plan: bootstrap-validate
	terraform -chdir=$(BOOTSTRAP_DIR) plan -out=$(BOOTSTRAP_PLAN_FILE)

bootstrap-apply:
	@if [ ! -f "$(BOOTSTRAP_DIR)/$(BOOTSTRAP_PLAN_FILE)" ]; then \
		echo "No saved bootstrap plan. Run 'make bootstrap-plan' first."; \
		exit 1; \
	fi
	terraform -chdir=$(BOOTSTRAP_DIR) apply $(BOOTSTRAP_PLAN_FILE)
	@rm -f $(BOOTSTRAP_DIR)/$(BOOTSTRAP_PLAN_FILE)

check-env:
	@if [ ! -d "$(TF_DIR)" ]; then \
		echo "Unknown ENV='$(ENV)'. Use dev, staging, or prod."; \
		exit 1; \
	fi

check-state-bucket:
	@if [ -z "$(STATE_BUCKET)" ]; then \
		echo "STATE_BUCKET is empty. Apply bootstrap first, or run:"; \
		echo "make init ENV=$(ENV) STATE_BUCKET=YOUR_STATE_BUCKET_NAME"; \
		exit 1; \
	fi

init: check-env check-state-bucket
	terraform -chdir=$(TF_DIR) init -input=false -reconfigure \
		-backend-config="bucket=$(STATE_BUCKET)"

validate: init
	terraform -chdir=$(TF_DIR) validate

plan: validate
	terraform -chdir=$(TF_DIR) plan -out=$(PLAN_FILE)

apply:
	@if [ ! -f "$(TF_DIR)/$(PLAN_FILE)" ]; then \
		echo "No saved plan at $(TF_DIR)/$(PLAN_FILE). Run 'make plan ENV=$(ENV)' first."; \
		exit 1; \
	fi
	terraform -chdir=$(TF_DIR) apply $(PLAN_FILE)
	@rm -f $(TF_DIR)/$(PLAN_FILE)

destroy-plan: validate
	terraform -chdir=$(TF_DIR) plan -destroy -out=$(DESTROY_PLAN_FILE)

destroy:
	@if [ ! -f "$(TF_DIR)/$(DESTROY_PLAN_FILE)" ]; then \
		echo "No saved destroy plan at $(TF_DIR)/$(DESTROY_PLAN_FILE). Run 'make destroy-plan ENV=$(ENV)' first."; \
		exit 1; \
	fi
	terraform -chdir=$(TF_DIR) apply $(DESTROY_PLAN_FILE)
	@rm -f $(TF_DIR)/$(DESTROY_PLAN_FILE)

output: init
	terraform -chdir=$(TF_DIR) output

url: init
	terraform -chdir=$(TF_DIR) output -raw cloudfront_url

fmt:
	terraform fmt -recursive

validate-all:
	terraform -chdir=$(BOOTSTRAP_DIR) init -input=false
	terraform -chdir=$(BOOTSTRAP_DIR) validate
	@for environment in dev staging prod; do \
		terraform -chdir=environments/$$environment init -backend=false -input=false; \
		terraform -chdir=environments/$$environment validate; \
	done
