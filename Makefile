.PHONY: help init plan apply destroy bootstrap deploy fmt validate outputs

TF_DIR := terraform

help:
	@echo "Targets:"
	@echo "  make init       - terraform init"
	@echo "  make plan       - terraform plan"
	@echo "  make apply      - create/update Hetzner + DNS"
	@echo "  make destroy    - tear down cloud resources (keeps floating IP if you remove it from config first)"
	@echo "  make outputs    - show IPs / URLs"
	@echo "  make bootstrap  - Path B via SSH: make bootstrap HOST=root@204.168.213.152 EMAIL=you@example.com"
	@echo "  make deploy     - git pull + docker compose on the server"
	@echo "  make fmt        - terraform fmt"
	@echo "  make validate   - terraform validate"
	@echo ""
	@echo "Path B (console one-liner) is documented in README.md"

init:
	cd $(TF_DIR) && terraform init

plan:
	cd $(TF_DIR) && terraform plan

apply:
	cd $(TF_DIR) && terraform apply

destroy:
	cd $(TF_DIR) && terraform destroy

outputs:
	cd $(TF_DIR) && terraform output

bootstrap:
	@test -n "$(HOST)" || (echo "HOST=user@ip required" && exit 1)
	@test -n "$(EMAIL)" || (echo "EMAIL=you@example.com required" && exit 1)
	./scripts/bootstrap-existing.sh "$(HOST)" "$(EMAIL)" "$(or $(DOMAIN),aveeus.ovh)"

deploy:
	./scripts/deploy.sh $(HOST)

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate: init
	cd $(TF_DIR) && terraform validate
