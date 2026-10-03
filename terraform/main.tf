locals {
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  labels = {
    project = "continuous-tunes"
    managed = "terraform"
  }
}

resource "hcloud_ssh_key" "deploy" {
  name       = "${var.server_name}-deploy"
  public_key = local.ssh_public_key
  labels     = local.labels
}

resource "hcloud_firewall" "web" {
  name   = "${var.server_name}-web"
  labels = local.labels

  rule {
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "ICMP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.allowed_ssh_cidrs
    description = "SSH"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP (ACME + redirect)"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }
}

resource "hcloud_network" "private" {
  name     = "${var.server_name}-net"
  ip_range = "10.0.0.0/16"
  labels   = local.labels
}

resource "hcloud_network_subnet" "private" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_floating_ip" "web" {
  count = var.use_floating_ip ? 1 : 0

  type          = "ipv4"
  home_location = var.location
  name          = "${var.server_name}-ipv4"
  labels        = local.labels
  description   = "Stable public IP for ${var.domain}"
}

resource "hcloud_server" "web" {
  name         = var.server_name
  server_type  = var.server_type
  location     = var.location
  image        = var.image
  ssh_keys     = [hcloud_ssh_key.deploy.id]
  labels       = local.labels
  firewall_ids = [hcloud_firewall.web.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    deploy_user       = var.deploy_user
    ssh_public_key    = local.ssh_public_key
    domain            = var.domain
    letsencrypt_email = var.letsencrypt_email
    infra_repo_url    = var.infra_repo_url
    infra_repo_branch = var.infra_repo_branch
    app_repo_url      = var.app_repo_url
    use_floating_ip   = var.use_floating_ip
    floating_ip       = var.use_floating_ip ? hcloud_floating_ip.web[0].ip_address : ""
  })

  depends_on = [hcloud_network_subnet.private]
}

resource "hcloud_server_network" "web" {
  server_id  = hcloud_server.web.id
  network_id = hcloud_network.private.id
  ip         = "10.0.1.10"
}

resource "hcloud_floating_ip_assignment" "web" {
  count = var.use_floating_ip ? 1 : 0

  floating_ip_id = hcloud_floating_ip.web[0].id
  server_id      = hcloud_server.web.id
}

data "cloudflare_zone" "site" {
  count = var.manage_dns ? 1 : 0
  name  = var.cloudflare_zone_name
}

locals {
  public_ipv4 = var.use_floating_ip ? hcloud_floating_ip.web[0].ip_address : hcloud_server.web.ipv4_address
}

resource "cloudflare_record" "apex" {
  count = var.manage_dns ? 1 : 0

  zone_id = data.cloudflare_zone.site[0].id
  name    = "@"
  type    = "A"
  content = local.public_ipv4
  ttl     = var.dns_proxied ? 1 : 300
  proxied = var.dns_proxied
  comment = "Managed by Terraform — Continuous-Tunes"
}

resource "cloudflare_record" "www" {
  count = var.manage_dns && var.create_www_cname ? 1 : 0

  zone_id = data.cloudflare_zone.site[0].id
  name    = "www"
  type    = "CNAME"
  content = var.domain
  ttl     = var.dns_proxied ? 1 : 300
  proxied = var.dns_proxied
  comment = "Managed by Terraform — Continuous-Tunes"
}

resource "local_file" "ssh_config" {
  filename        = "${path.module}/../.generated/ssh_config"
  content         = <<-EOT
    Host avedeus
      HostName ${hcloud_server.web.ipv4_address}
      User ${var.deploy_user}
      IdentityFile ${pathexpand(var.ssh_private_key_path)}
      StrictHostKeyChecking accept-new
  EOT
  file_permission = "0644"
}
