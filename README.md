# Azure Landing Zone Factory

An enterprise-scale Azure Landing Zone implementation using Terraform, aligned to the **Microsoft Cloud Adoption Framework (CAF)** and **Azure Landing Zone conceptual architecture**. Deploys a complete organisational foundation including management group hierarchy, hub-spoke networking, Azure Firewall, centralised logging, and governance policies as code.

---

## Solution Overview

### Problem Statement
Organisations moving workloads to Azure without a Landing Zone foundation frequently accumulate unstructured subscriptions, inconsistent security controls, ungoverned networking, and no centralised visibility. Retrofitting governance onto an existing environment is significantly more expensive and disruptive than establishing it upfront.

### Architecture Approach
This factory deploys the foundational Azure platform layer that all workload subscriptions sit on top of. It follows the CAF Enterprise Scale pattern with a management group hierarchy separating platform, landing zone, sandbox, and decommissioned workloads. All governance is applied at the management group level using Azure Policy, ensuring every child subscription inherits controls automatically without manual configuration.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Management Group Hierarchy                    │
│                                                                  │
│  [Tenant Root]                                                   │
│      └── [Org Root]                                              │
│              ├── [Platform]                                      │
│              │       ├── Management Subscription                 │
│              │       ├── Connectivity Subscription               │
│              │       └── Identity Subscription                   │
│              ├── [Landing Zones]                                 │
│              │       └── [Corp]  ← Workload subscriptions        │
│              ├── [Sandbox]       ← Dev/test subscriptions        │
│              └── [Decommissioned]                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Hub Network Architecture                      │
│                                                                  │
│  Hub VNet (10.0.0.0/16)                                         │
│  ├── GatewaySubnet       - VPN/ExpressRoute Gateway             │
│  ├── AzureFirewallSubnet - Azure Firewall (central egress)       │
│  └── AzureBastionSubnet  - Secure VM access (no public SSH/RDP) │
│                                                                  │
│  Spoke VNets peer to Hub and route all traffic via Firewall      │
└─────────────────────────────────────────────────────────────────┘
```

---

## What Gets Deployed

| Component | Resource | Purpose |
|-----------|----------|---------|
| Management Groups | 6 group hierarchy | Organisational structure and policy inheritance |
| Hub Virtual Network | VNet + 3 subnets | Central network hub for all spoke connectivity |
| Azure Firewall | Standard tier | Centralised egress control and threat intelligence |
| Azure Bastion | Standard tier | Secure VM access without public IP exposure |
| Log Analytics Workspace | 90 day retention | Centralised logging for all platform resources |
| Azure Policy | 4 assignments | Tag enforcement, location restriction, monitoring |
| Diagnostic Settings | Firewall to LAW | Full firewall log visibility in Log Analytics |

---

## Project Structure

```
azure-landing-zone-factory/
├── terraform/
│   ├── main.tf           # All Landing Zone resources
│   ├── variables.tf      # Input variable definitions with validation
│   └── outputs.tf        # Resource IDs and connection strings
├── docs/
│   └── architecture.md   # Detailed architecture decisions
└── README.md
```

---

## Requirements

- Terraform >= 1.5.0
- AzureRM provider ~> 3.90
- Owner role on the Azure tenant root management group
- Azure subscription for management/hub resources

---

## Deployment

### 1. Initialise

```bash
cd terraform
terraform init
```

### 2. Configure Variables

```hcl
# terraform.tfvars
org_prefix                 = "contoso"
management_subscription_id = "00000000-0000-0000-0000-000000000000"
primary_location           = "australiaeast"
environment                = "Production"
cost_center                = "IT-001"
hub_address_space          = "10.0.0.0/16"
allowed_locations          = ["australiaeast", "australiasoutheast"]
```

### 3. Plan and Apply

```bash
terraform plan -out=lz.tfplan
terraform apply lz.tfplan
```

---

## Key Design Decisions

**Management groups over subscriptions for policy.** Assigning Azure Policy at the management group level means every new subscription created under that group automatically inherits all governance controls. This eliminates the need to manually apply policies to each new subscription and prevents governance gaps as the environment grows.

**Azure Firewall as the single egress point.** All spoke VNets route internet-bound traffic through the hub Azure Firewall via User Defined Routes. This provides centralised threat intelligence filtering, application rule enforcement, and full egress logging in a single place rather than managing NSGs across dozens of spoke networks.

**Bastion over jump boxes.** Azure Bastion provides browser-based RDP and SSH access to VMs without requiring public IPs or open inbound ports. This eliminates an entire class of attack surface that traditional jump box architectures introduce.

**DeployIfNotExists policy for monitoring.** Rather than relying on teams to remember to configure monitoring on new VMs, the Azure Monitor Agent policy automatically deploys the agent to any non-compliant VM. This ensures monitoring coverage is maintained automatically as the environment grows.

**Log retention validation.** The `log_retention_days` variable has a built-in Terraform validation rule enforcing a minimum of 90 days, preventing accidental deployment with retention periods that would fail Essential Eight or PCI DSS audit requirements.

---

## Roadmap

- Spoke VNet module for automated workload subscription vending
- Azure DevOps pipeline for plan and apply with approval gate
- Azure Policy custom initiative for Essential Eight controls
- Microsoft Defender for Cloud auto-provisioning configuration
- Private DNS zones for all Azure PaaS services

---

## Author

**Daniel Tousi**
Principal Engineer | Cloud Solution Architect | Azure | Microsoft 365 | Hybrid Infrastructure

[![LinkedIn](https://img.shields.io/badge/LinkedIn-danieltousi-0A66C2?style=flat&logo=linkedin)](https://www.linkedin.com/in/daniel-tousi-19293563/)
[![GitHub](https://img.shields.io/badge/GitHub-danieltousi-181717?style=flat&logo=github)](https://github.com/danieltousi)

---

## References

- [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/)
- [Azure Landing Zone Architecture](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Policy Built-in Definitions](https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies)
- [Hub-Spoke Network Topology](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
