variable "org_prefix" {
  description = "Short organisation prefix used in resource naming."
  type        = string
}

variable "management_subscription_id" {
  description = "Azure subscription ID for the management/hub subscription."
  type        = string
  sensitive   = true
}

variable "primary_location" {
  description = "Primary Azure region for resource deployment."
  type        = string
  default     = "australiaeast"
}

variable "environment" {
  description = "Environment tag value applied to all resources."
  type        = string
  default     = "Production"
}

variable "cost_center" {
  description = "Cost center tag value for billing attribution."
  type        = string
}

variable "hub_address_space" {
  description = "Address space for the hub virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "gateway_subnet_prefix" {
  description = "Address prefix for the GatewaySubnet."
  type        = string
  default     = "10.0.0.0/27"
}

variable "firewall_subnet_prefix" {
  description = "Address prefix for the AzureFirewallSubnet."
  type        = string
  default     = "10.0.1.0/26"
}

variable "bastion_subnet_prefix" {
  description = "Address prefix for the AzureBastionSubnet."
  type        = string
  default     = "10.0.2.0/27"
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention period in days. Minimum 90 for Essential Eight compliance."
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "Log retention must be at least 90 days to meet Essential Eight requirements."
  }
}

variable "allowed_locations" {
  description = "List of allowed Azure regions. Restricts where resources can be deployed across the organisation."
  type        = list(string)
  default     = ["australiaeast", "australiasoutheast"]
}
