variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "forgejo_api_token" {
  type      = string
  sensitive = true
}

variable "unifi_api_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type    = string
  default = "7d4e6e95bf7ff3d09d92e7903193826b"
}

variable "access_editor_emails" {
  type      = list(string)
  sensitive = true
}
