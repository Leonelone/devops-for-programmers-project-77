### Hexlet tests and linter status:
[![Actions Status](https://github.com/Leonelone/devops-for-programmers-project-77/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Leonelone/devops-for-programmers-project-77/actions)

## Terraform Infrastructure (Yandex Cloud)

This project provisions:

- Two VM web servers with nginx serving HTTPS (self-signed TLS)
- Network Load Balancer listening on TCP:443 spreading traffic across VMs
- Managed PostgreSQL (Yandex Managed DB) cluster, database and user

### Prerequisites

- Terraform >= 1.3
- Yandex Cloud account and OAuth token
- SSH public key at `~/.ssh/id_rsa.pub`

Set environment variable before running commands:

```bash
export YC_TOKEN=<your_yandex_cloud_oauth_token>
```

Optional variables can be overridden via `terraform.tfvars` or `-var` flags:

- `yc_folder_id` (default set in `terraform/main.tf`)
- `vpc_network_id` (existing VPC network)
- `zone` (default `ru-central1-a`)

### Usage

Initialize backend and providers:

```bash
make init
```

Plan changes:

```bash
make plan
```

Apply infrastructure:

```bash
make apply
```

Show outputs (VM IPs, NLB address, PostgreSQL FQDN):

```bash
make output
```

Destroy infrastructure:

```bash
make destroy
```

### Notes

- NLB performs TCP load balancing on port 443; each VM serves nginx with a self-signed certificate created via cloud-init.
- PostgreSQL credentials are created as resources; consider storing sensitive values in a secure place and rotating the default password.
- If using remote Terraform backend (e.g., Terraform Cloud), do not interrupt pending operations only locally; cancel via CLI or Terraform Cloud UI if needed.

## Ansible Deployment

All Ansible files are under `ansible/`:

- `playbook.yml` — main playbook for preparation and deployment
- `requirements.yml` — external roles and collections
- `inventory.ini` — generated from Terraform outputs
- `ansible.cfg` — Ansible configuration

Secrets must not be committed. Use Ansible Vault for sensitive values:

```bash
ansible-vault create ansible/group_vars/all/vault.yml
# then reference with vars_files in your playbook if needed
```

### Prepare

```bash
make ansible-prepare
```

This installs roles/collections and generates inventory from Terraform outputs, then pings all hosts.

### Deploy

```bash
make ansible-deploy
```

This runs the play with tags `docker,deploy,nginx` to install Docker and run the app container behind nginx TLS.

To run only a subset of tasks, pass tags explicitly:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbook.yml -t deploy
```

## Domain and DNS

- Registrar: register a domain (e.g., `hexlet-student.ru`).
- After `make apply`, get name servers and IP via outputs:

```bash
make output
# dns_zone_name_servers = ["ns1.yandexcloud.net.", "ns2.yandexcloud.net."]
# nlb_public_address    = 203.0.113.10
# app_domain            = hexlet-student.ru
```

Steps:
- In your registrar panel, set NS to values from `dns_zone_name_servers`.
- Wait for delegation to propagate (can take hours).
- The Terraform DNS zone creates an A record for the root domain pointing to the NLB IP.

Your app will be available at:

```text
https://hexlet-student.ru
```

### TLS via Let’s Encrypt

After DNS delegation propagates, request and configure certificates:

```bash
make ansible-tls
```

This installs certbot, obtains a certificate for `hexlet-student.ru`, and reconfigures nginx to use it.