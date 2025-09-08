variable "enable_datadog" { default = false }
variable "datadog_api_key" { default = "" }
variable "datadog_app_key" { default = "" }
variable "datadog_site" { default = "datadoghq.com" }
variable "app_domain" { default = "" }

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}"
  validate = var.enable_datadog
}

resource "datadog_synthetics_test" "webapp_https" {
  count   = var.enable_datadog ? 1 : 0
  type    = "api"
  subtype = "http"
  request_definition {
    method = "GET"
    url    = "https://${var.app_domain}/"
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
  assertion {
    type     = "statusCode"
    operator = "is"
    target   = 200
  }
  name    = "Webapp HTTPS check"
  message = "Webapp is not returning 200 at https://${var.app_domain}/"
  locations = ["aws:eu-central-1"]
  tags      = ["env:prod", "app:webapp"]
  status    = "live"
}

output "datadog_test_id" {
  value       = var.enable_datadog ? datadog_synthetics_test.webapp_https[0].id : null
  description = "ID of the Datadog synthetics test (when enabled)"
}

