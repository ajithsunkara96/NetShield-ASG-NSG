// Optional: Terraform skeleton (not wired end-to-end)
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

# TODO: vnet, subnets, asgs, nsgs, three VMs
