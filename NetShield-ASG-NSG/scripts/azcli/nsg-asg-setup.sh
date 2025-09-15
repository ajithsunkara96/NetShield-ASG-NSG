#!/usr/bin/env bash
# Create ASGs, NSG rules, and demonstrate app->web allow on 8080 + deny app->db
set -euo pipefail

RG=${RG:-netshield-rg}
LOC=${LOC:-canadacentral}

echo "Using RG=$RG LOC=$LOC"

# Example: add an explicit NSG rule allowing app ASG to web ASG on 8080
az network nsg rule create -g "$RG" --nsg-name nsg-web   -n allow-app-to-web-8080 --priority 100   --direction Inbound --access Allow --protocol Tcp   --source-asgs asg-app --destination-asgs asg-web   --destination-port-ranges 8080

# Example: deny any to db ASG (defense in depth)
az network nsg rule create -g "$RG" --nsg-name nsg-web   -n deny-any-to-db --priority 200   --direction Inbound --access Deny --protocol '*'   --source-address-prefixes '*' --destination-asgs asg-db   --destination-port-ranges '*'
