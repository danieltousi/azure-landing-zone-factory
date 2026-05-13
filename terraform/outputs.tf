output "management_group_ids" {
  description = "Management group resource IDs"
  value = {
    root            = azurerm_management_group.root.id
    platform        = azurerm_management_group.platform.id
    landing_zones   = azurerm_management_group.landing_zones.id
    corp            = azurerm_management_group.corp.id
    sandbox         = azurerm_management_group.sandbox.id
    decommissioned  = azurerm_management_group.decommissioned.id
  }
}

output "hub_vnet_id" {
  description = "Hub virtual network resource ID"
  value       = azurerm_virtual_network.hub.id
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace resource ID"
  value       = azurerm_log_analytics_workspace.central.id
}

output "log_analytics_workspace_key" {
  description = "Central Log Analytics workspace primary key"
  value       = azurerm_log_analytics_workspace.central.primary_shared_key
  sensitive   = true
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP for use as UDR next hop"
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}
