# Azure Landing Zone Factory
# Author: Daniel Tousi
# Description: Enterprise-scale Landing Zone with management groups, policies,
# hub-spoke networking, and subscription vending aligned to Microsoft CAF

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "landing-zone/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.management_subscription_id
}

#region --- Management Group Hierarchy ---

resource "azurerm_management_group" "root" {
  display_name = "${var.org_prefix} Root"
}

resource "azurerm_management_group" "platform" {
  display_name               = "${var.org_prefix} Platform"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "landing_zones" {
  display_name               = "${var.org_prefix} Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "corp" {
  display_name               = "${var.org_prefix} Corp"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "sandbox" {
  display_name               = "${var.org_prefix} Sandbox"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "decommissioned" {
  display_name               = "${var.org_prefix} Decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}

#endregion

#region --- Hub Network Subscription ---

resource "azurerm_resource_group" "hub_network" {
  name     = "rg-hub-network-${var.primary_location}"
  location = var.primary_location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.primary_location}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.hub_network.name
  address_space       = [var.hub_address_space]
  tags                = local.common_tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub_network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub_network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub_network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

#endregion

#region --- Azure Firewall ---

resource "azurerm_public_ip" "firewall" {
  name                = "pip-azfw-hub-${var.primary_location}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.hub_network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_firewall" "hub" {
  name                = "azfw-hub-${var.primary_location}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.hub_network.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = local.common_tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

#endregion

#region --- Azure Bastion ---

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-hub-${var.primary_location}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.hub_network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_bastion_host" "hub" {
  name                = "bastion-hub-${var.primary_location}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.hub_network.name
  tags                = local.common_tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

#endregion

#region --- Log Analytics Workspace ---

resource "azurerm_resource_group" "management" {
  name     = "rg-management-${var.primary_location}"
  location = var.primary_location
  tags     = local.common_tags
}

resource "azurerm_log_analytics_workspace" "central" {
  name                = "law-central-${var.primary_location}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.management.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-azfw-to-law"
  target_resource_id         = azurerm_firewall.hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id

  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#endregion

#region --- Azure Policy Assignments ---

# Require tags on resource groups
resource "azurerm_policy_assignment" "require_tags" {
  name                 = "require-rg-tags"
  display_name         = "Require tags on resource groups"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
  scope                = azurerm_management_group.root.id

  parameters = jsonencode({
    tagName = { value = "Environment" }
  })
}

# Deny public IP creation in corp landing zone
resource "azurerm_policy_assignment" "deny_public_ip_corp" {
  name                 = "deny-public-ip-corp"
  display_name         = "Deny public IP creation in Corp landing zone"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
  scope                = azurerm_management_group.corp.id
  enforcement_mode     = "Default"
}

# Enforce allowed locations
resource "azurerm_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Azure regions"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  scope                = azurerm_management_group.root.id

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

# Deploy Azure Monitor agent via DeployIfNotExists
resource "azurerm_policy_assignment" "deploy_monitor_agent" {
  name                 = "deploy-ama"
  display_name         = "Deploy Azure Monitor Agent on VMs"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a4417263-694d-4223-b48d-e7c2bc14f985"
  scope                = azurerm_management_group.root.id
  enforcement_mode     = "Default"

  identity {
    type = "SystemAssigned"
  }

  location = var.primary_location
}

#endregion

#region --- Locals ---

locals {
  common_tags = {
    Environment  = var.environment
    ManagedBy    = "Terraform"
    Organisation = var.org_prefix
    CostCenter   = var.cost_center
  }
}

#endregion
