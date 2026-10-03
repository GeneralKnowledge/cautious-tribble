terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "hcloud" {
  # Auth: export HCLOUD_TOKEN=...
}

provider "cloudflare" {
  # Auth: export CLOUDFLARE_API_TOKEN=...
  # Only required when var.manage_dns = true
}
