TF_DIR=terraform
ANSIBLE_DIR=ansible

.PHONY: init plan apply destroy output fmt validate

init:
	cd $(TF_DIR) && terraform init -input=false

plan:
	cd $(TF_DIR) && TERRAFORM_CONFIG=$(PWD)/.terraformrc terraform plan -input=false -var yc_token=$$YC_TOKEN

apply:
	cd $(TF_DIR) && TERRAFORM_CONFIG=$(PWD)/.terraformrc terraform apply -auto-approve -input=false -var yc_token=$$YC_TOKEN

destroy:
	cd $(TF_DIR) && TERRAFORM_CONFIG=$(PWD)/.terraformrc terraform destroy -auto-approve -input=false -var yc_token=$$YC_TOKEN

.PHONY: datadog-plan datadog-apply

datadog-plan:
	cd $(TF_DIR) && terraform plan -input=false -var yc_token=$$YC_TOKEN -var enable_datadog=true -var datadog_api_key=$$DATADOG_API_KEY -var datadog_app_key=$$DATADOG_APP_KEY -var app_domain=$$(terraform output -raw app_domain)

datadog-apply:
	cd $(TF_DIR) && terraform apply -auto-approve -input=false -var yc_token=$$YC_TOKEN -var enable_datadog=true -var datadog_api_key=$$DATADOG_API_KEY -var datadog_app_key=$$DATADOG_APP_KEY -var app_domain=$$(terraform output -raw app_domain)

# Compatibility targets (as in the referenced repo)
.PHONY: install terrafrom-start ansible-start

install: ansible-requirements

terrafrom-start: init apply

ansible-start: ansible-prepare ansible-deploy

output:
	cd $(TF_DIR) && terraform output

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate:
	cd $(TF_DIR) && terraform validate

.PHONY: ansible-requirements ansible-inventory ansible-prepare ansible-deploy

ansible-requirements:
	cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml --force

ansible-inventory:
	python3 $(ANSIBLE_DIR)/scripts/generate_inventory.py

ansible-prepare: ansible-requirements ansible-inventory
	ANSIBLE_CONFIG=$(ANSIBLE_DIR)/ansible.cfg ansible -i $(ANSIBLE_DIR)/inventory.ini all -m ping

.PHONY: ansible-datadog ansible-vault-create

ansible-datadog:
	ANSIBLE_CONFIG=$(ANSIBLE_DIR)/ansible.cfg ansible-playbook $(ANSIBLE_DIR)/playbook.yml -t datadog -e @ansible/group_vars/all/vault.yml --ask-vault-pass

ansible-vault-create:
	ansible-vault create ansible/group_vars/all/vault.yml

ansible-deploy:
	ANSIBLE_CONFIG=$(ANSIBLE_DIR)/ansible.cfg ansible-playbook $(ANSIBLE_DIR)/playbook.yml -t docker,deploy,nginx

ansible-tls:
	ANSIBLE_CONFIG=$(ANSIBLE_DIR)/ansible.cfg ansible-playbook $(ANSIBLE_DIR)/playbook.yml -t tls

# Hexlet-compatible targets
.PHONY: create_structure install_app create_balancer deploy_all destroy_all

create_structure: init apply

install_app: ansible-prepare ansible-deploy

create_balancer:
	# Балансировщик создается вместе с инфраструктурой
	@echo "NLB создается в Terraform apply; дополнительных действий не требуется"

deploy_all: create_structure install_app

destroy_all: destroy