terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = ">= 3.40.0"
    }
  }
}

variable "datadog_api_key" {}
variable "datadog_app_key" {}
variable "datadog_site" { default = "datadoghq.com" }

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}"
}

data "external" "app_domain" {
  program = ["bash", "-lc", "terraform output -raw app_domain || true"]
}

locals {
  app_domain = coalesce(try(data.external.app_domain.result["output"], null), "hexlet-student.ru")
}

resource "datadog_synthetics_test" "webapp_https" {
  type    = "api"
  subtype = "http"
  request_definition {
    method = "GET"
    url    = "https://${local.app_domain}/"
  }
  options_list {
    tick_every            = 300
    follow_redirects      = true
    min_failure_duration  = 0
    min_location_failed   = 1
    retry {
      count    = 2
      interval = 300
    }
  }
  assertions {
    type     = "statusCode"
    operator = "is"
    target   = 200
  }
  name    = "Webapp HTTPS check"
  message = "Webapp is not returning 200 at https://${local.app_domain}/ @slack-ops"
  locations = ["aws:eu-central-1"]
  tags      = ["env:prod", "app:webapp"]
  status    = "live"
}

output "datadog_test_public_id" {
  value = datadog_synthetics_test.webapp_https.public_id
}

