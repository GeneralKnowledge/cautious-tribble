variable "server_name" {
  description = "Hetzner Cloud server name"
  type        = string
  default     = "avedeus"
}

variable "server_type" {
  description = "Hetzner server type (CX22 = 2 vCPU / 4 GB)"
  type        = string
  default     = "cx22"
}

variable "location" {
  description = "Hetzner location (nbg1, fsn1, hel1, ash, hil)"
  type        = string
  default     = "nbg1"
}

variable "image" {
  description = "OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key provisioned on the server"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the matching SSH private key (used by generated deploy helpers)"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "domain" {
  description = "Public domain for Continuous-Tunes"
  type        = string
  default     = "avedeus.ovh"
}

variable "manage_dns" {
  description = "Create/update Cloudflare A (and optional www) records"
  type        = bool
  default     = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name (usually same as domain)"
  type        = string
  default     = "avedeus.ovh"
}

variable "dns_proxied" {
  description = "Proxy the domain through Cloudflare (orange cloud). Set false for DNS-only."
  type        = bool
  default     = false
}

variable "create_www_cname" {
  description = "Also create www.<domain> as a CNAME to the apex"
  type        = bool
  default     = true
}

variable "use_floating_ip" {
  description = "Attach a Hetzner floating IP so recreating the server does not change the public address"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH (default: anywhere — tighten this)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "app_repo_url" {
  description = "Git URL of Continuous-Tunes (used by cloud-init clone)"
  type        = string
  default     = "https://github.com/GeneralKnowledge/Continuous-Tunes.git"
}

variable "infra_repo_url" {
  description = "Git URL of this infrastructure repo (cloned onto the server)"
  type        = string
  default     = "https://github.com/GeneralKnowledge/cautious-tribble.git"
}

variable "infra_repo_branch" {
  description = "Branch of this infrastructure repo to deploy"
  type        = string
  default     = "main"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt / Caddy ACME registration"
  type        = string
}

variable "deploy_user" {
  description = "Non-root user created on the server"
  type        = string
  default     = "deploy"
}
