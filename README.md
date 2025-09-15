# NetShield — ASG/NSG‑Driven Multi‑Tier Security on Azure

Implement a three‑tier Azure network (web, app, db) using **Network Security Groups (NSGs)** and **Application Security Groups (ASGs)** with basic monitoring and alerting. This repo reconstructs the artifacts behind my resume project so others can review, learn, or reproduce it locally in their Azure subscription.

> Stack: Azure VNet/Subnets · Ubuntu VMs · NSGs · ASGs · Azure Monitor (Metrics/Alerts/Logs) · KQL

## Architecture

```mermaid
flowchart LR
  Internet((Internet)) -->|8080| WebVM[web-vm]

  subgraph NetShieldVnet
    direction LR
    subgraph Web["web-subnet"]
      WebVM
    end
    subgraph App["app-subnet"]
      AppVM[app-vm]
    end
    subgraph DB["db-subnet"]
      DbVM[db-vm]
    end
  end

  WebVM <-->|App-only| AppVM
  AppVM -.->|Denied| DbVM

**Traffic policy highlights**
- Allow `app -> web` on tcp/8080 (via ASG/NSG rules)
- Deny `app -> db` (explicit deny to show isolation)
- Internet ingress only to web tier (optional: via 8080 for demo)

## Reproduce (quick start)

> Requires: Azure CLI logged in (`az login`), Owner/Contributor rights on target subscription, and SSH key present.

```bash
# 1) Deploy base infra (VNet, subnets, ASGs, NSGs, 3 Ubuntu VMs)
az deployment sub create   --name netshield-bicep-$(date +%Y%m%d%H%M)   --location canadacentral   --template-file infra/bicep/main.bicep   --parameters adminUsername=$USER

# 2) Apply demo NSG rules if you prefer CLI snippets
bash scripts/azcli/nsg-asg-setup.sh

# 3) Start a simple http server on web-vm and test from app-vm
# (see docs/DEMO.md)
```

## Monitoring & Alerts

- Sample CPU alert rule for `db-vm` exceeds 60% (ARM template in `monitoring/alerts/dbvm_cpu_60.json`)
- Basic KQL queries for metrics & perf in `monitoring/kql`

## Repository layout

```
infra/
  bicep/          Bicep IaC for VNet, subnets, ASGs/NSGs, and three VMs
  terraform/      Skeleton terraform (optional)
scripts/
  azcli/          One‑shot Azure CLI scripts to create ASGs/NSGs and test rules
monitoring/
  kql/            Handy Log Analytics (KQL) snippets
  alerts/         ARM template for CPU alert
docs/
  DEMO.md         Step‑by‑step demo (http.server + curl tests)
.github/workflows/
  validate-bicep.yml  Lints Bicep on PRs
```

## Notes

- This is a **learning/demo** deployment; tighten for production (private endpoints, Azure Bastion, no public IPs on app/db, etc.).
- All resources default to **Canada Central** and small SKUs to keep costs low.

---

© 2025 NetShield demo. Licensed under MIT.
