@description('Name of the VM')
param vmName string

@description('Subnet resource ID to attach NIC')
param subnetId string

@description('NSG ID to attach at NIC-level')
param nsgId string

@description('Application Security Group IDs to attach to NIC')
param asgIds array

@description('Azure region')
param location string = resourceGroup().location

@description('Linux admin username')
param adminUsername string

@description('SSH public key for ~/.ssh/authorized_keys')
param adminPublicKey string

@description('Whether to create a public IP (true for web-vm, false otherwise)')
param publicIP bool = false

// Optional Public IP (demo uses it for web-vm)
resource pip 'Microsoft.Network/publicIPAddresses@2024-03-01' = if (publicIP) {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// NIC with NSG + ASGs (ASG membership belongs at NIC level)
resource nic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: publicIP ? {
            id: pip.id
          } : null
          applicationSecurityGroups: [
            for id in asgIds: {
              id: id
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
}

// Linux VM with SSH key auth only
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Outputs
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress

// SAFE: Build the PIP resource ID by name; only reference it when publicIP is true.
// This avoids dereferencing a possibly-null NIC property or a conditional resource symbol.
var pipResourceId = resourceId('Microsoft.Network/publicIPAddresses', '${vmName}-pip')

output publicIp string = publicIP
  ? string(reference(pipResourceId, '2024-03-01').ipAddress)
  : ''
