output "server_ipv4" {
  description = "Server primary IPv4 (changes if the server is recreated without a floating IP)"
  value       = hcloud_server.web.ipv4_address
}

output "public_ipv4" {
  description = "Address that DNS should point at (floating IP when enabled)"
  value       = local.public_ipv4
}

output "server_ipv6" {
  description = "Server primary IPv6"
  value       = hcloud_server.web.ipv6_address
}

output "floating_ip" {
  description = "Floating IPv4 when use_floating_ip = true"
  value       = var.use_floating_ip ? hcloud_floating_ip.web[0].ip_address : null
}

output "domain" {
  value = var.domain
}

output "ssh_host" {
  description = "SSH alias written to .generated/ssh_config"
  value       = "avedeus"
}

output "ssh_command" {
  value = "ssh -F .generated/ssh_config avedeus"
}

output "app_url" {
  value = "https://${var.domain}"
}

output "recreate_hint" {
  value = "To wipe and rebuild: terraform destroy -auto-approve && terraform apply -auto-approve"
}
