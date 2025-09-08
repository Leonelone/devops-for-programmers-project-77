TF_DIR=terraform
ANSIBLE_DIR=ansible

.PHONY: init plan apply destroy output fmt validate

init:
	cd $(TF_DIR) && terraform init -input=false

plan:
	cd $(TF_DIR) && terraform plan -input=false -var yc_token=$$YC_TOKEN

apply:
	cd $(TF_DIR) && terraform apply -auto-approve -input=false -var yc_token=$$YC_TOKEN

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve -input=false -var yc_token=$$YC_TOKEN

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

ansible-deploy:
	ANSIBLE_CONFIG=$(ANSIBLE_DIR)/ansible.cfg ansible-playbook $(ANSIBLE_DIR)/playbook.yml -t docker,deploy,nginx

ansible-tls:
	ANSIBLE_CONFIG=$(ANSIBLE_DIR)/ansible.cfg ansible-playbook $(ANSIBLE_DIR)/playbook.yml -t tls

