terraform {
  required_version = ">= 1.3.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.94.0"
    }
    datadog = {
      source  = "datadog/datadog"
      version = ">= 3.40.0"
    }
  }
}

variable "yc_token" {}
variable "yc_folder_id" { default = "b1g1jelqj78qvsqtnlbt" }
variable "vpc_network_id" { default = "enp1ugr79lcmibrdpbs9" }
variable "zone" { default = "ru-central1-a" }

provider "yandex" {
  token      = var.yc_token
  folder_id  = var.yc_folder_id
  zone       = var.zone
}

data "yandex_vpc_network" "existing" {
  network_id = var.vpc_network_id
}

resource "yandex_vpc_subnet" "default" {
  name           = "hexlet-subnet"
  zone           = var.zone
  network_id     = var.vpc_network_id
  v4_cidr_blocks = ["10.5.0.0/24"]
  folder_id      = var.yc_folder_id
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

locals {
  web_instance_count = 1
  web_user_data = <<-EOT
              #cloud-config
              package_update: true
              packages:
                - nginx
                - openssl
              runcmd:
                - mkdir -p /etc/nginx/ssl
                - openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/selfsigned.key -out /etc/nginx/ssl/selfsigned.crt -subj "/CN=example.local"
                - printf 'server {\n  listen 443 ssl;\n  server_name _;\n  ssl_certificate /etc/nginx/ssl/selfsigned.crt;\n  ssl_certificate_key /etc/nginx/ssl/selfsigned.key;\n  location / { return 200 "Hello from $(hostname)\\n"; }\n}\n' > /etc/nginx/sites-available/default
                - systemctl restart nginx
  EOT
}

resource "yandex_compute_instance" "web" {
  count       = local.web_instance_count
  name        = "web-${count.index}"
  platform_id = "standard-v1"
  zone        = var.zone
  folder_id   = var.yc_folder_id

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = var.vpc_network_id
    nat = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = local.web_user_data
  }
}

resource "yandex_lb_target_group" "web_tg" {
  name      = "web-tg"
  folder_id = var.yc_folder_id

  dynamic "target" {
    for_each = yandex_compute_instance.web
    content {
      subnet_id = yandex_vpc_subnet.default.id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "nlb" {
  name      = "web-nlb"
  folder_id = var.yc_folder_id

  listener {
    name = "https-tcp"
    port = 443
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name = "http-tcp"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_tg.id

    healthcheck {
      name                = "tcp-443"
      tcp_options {
        port = 443
      }
      interval            = 5
      timeout             = 3
      unhealthy_threshold = 2
      healthy_threshold   = 2
    }
  }
}

# DNS zone for the domain and A-record to the NLB public IP
variable "domain_name" { default = "hexlet-student.ru" }

resource "yandex_dns_zone" "primary" {
  name        = "primary-zone"
  description = "Primary public zone for application"
  zone        = "${var.domain_name}."
  public      = true
  folder_id   = var.yc_folder_id
}

resource "yandex_dns_recordset" "root_a" {
  zone_id = yandex_dns_zone.primary.id
  name    = "${var.domain_name}."
  type    = "A"
  ttl     = 300
  data    = [for l in yandex_lb_network_load_balancer.nlb.listener : l.external_address_spec[0].address if l.port == 443]
}

# Managed PostgreSQL cluster
resource "yandex_mdb_postgresql_cluster" "pg" {
  name        = "webapp-pg"
  environment = "PRESTABLE"
  network_id  = var.vpc_network_id
  folder_id   = var.yc_folder_id
  config {
    version = 15
    resources {
      resource_preset_id = "s2.micro"
      disk_size          = 20
      disk_type_id       = "network-ssd"
    }
    postgresql_config = {
      max_connections = 100
    }
  }
  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.default.id
    assign_public_ip = true
  }
}

resource "yandex_mdb_postgresql_database" "db" {
  cluster_id = yandex_mdb_postgresql_cluster.pg.id
  name       = "app_db"
  owner      = yandex_mdb_postgresql_user.app.name
}

resource "yandex_mdb_postgresql_user" "app" {
  cluster_id = yandex_mdb_postgresql_cluster.pg.id
  name       = "app_user"
  password   = "app_password_ChangeMe123"
}

output "web_public_ips" {
  value = [for i in yandex_compute_instance.web : i.network_interface.0.nat_ip_address]
}

output "nlb_public_address" {
  value = [for l in yandex_lb_network_load_balancer.nlb.listener : l.external_address_spec[0].address if l.port == 443][0]
}

output "postgres_fqdn" {
  value = yandex_mdb_postgresql_cluster.pg.host[0].fqdn
}

output "dns_zone_name_servers" {
  value = yandex_dns_zone.primary.zone
}

output "app_domain" {
  value = var.domain_name
}
