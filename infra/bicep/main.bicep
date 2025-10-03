@description('Azure region for all resources')
param location string = 'canadacentral'

@description('Linux admin username for all VMs')
param adminUsername string = 'azureuser'

@description('SSH public key to inject into all VMs (~/.ssh/authorized_keys)')
param adminPublicKey string

@description('Optional: your public IP/CIDR to allow SSH to web-vm (e.g., 203.0.113.5/32). Leave empty to skip.')
param adminSshCidr string = ''

@description('If true, allow SSH jump from web -> app (asg-web -> asg-app :22) for testing.')
param enableJumpSsh bool = true

// ---- Names ----
var vnetName       = 'NetShieldVnet'
var webSubnetName  = 'web-subnet'
var appSubnetName  = 'app-subnet'
var dbSubnetName   = 'db-subnet'

// ---- VNet + subnets (we attach NSGs at NIC-level in vm.bicep) ----
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: webSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: dbSubnetName
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
}

// ---- ASGs (labels for NICs) ----
resource asgWeb 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: 'asg-web'
  location: location
}
resource asgApp 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: 'asg-app'
  location: location
}
resource asgDb 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: 'asg-db'
  location: location
}

// ---- NSGs (inbound rules live on the destination tier) ----
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: 'nsg-web'
  location: location
  properties: {
    securityRules: concat(
      // Optional SSH from your IP to web:22
      empty(adminSshCidr) ? [] : [
        {
          name: 'allow-adminip-to-web-22'
          properties: {
            priority: 110
            direction: 'Inbound'
            access: 'Allow'
            protocol: 'Tcp'
            sourceAddressPrefix: adminSshCidr
            sourcePortRange: '*'
            destinationApplicationSecurityGroups: [
              { id: asgWeb.id }
            ]
            destinationPortRange: '22'
          }
        }
      ],
      [
        // Allow app -> web on tcp/8080
        {
          name: 'allow-app-to-web-8080'
          properties: {
            priority: 100
            direction: 'Inbound'
            access: 'Allow'
            protocol: 'Tcp'
            sourceApplicationSecurityGroups: [
              { id: asgApp.id }
            ]
            sourcePortRange: '*'
            destinationApplicationSecurityGroups: [
              { id: asgWeb.id }
            ]
            destinationPortRange: '8080'
          }
        }
        // Allow Internet -> web on tcp/8080
        {
          name: 'allow-internet-to-web-8080'
          properties: {
            priority: 300
            direction: 'Inbound'
            access: 'Allow'
            protocol: 'Tcp'
            sourceAddressPrefix: 'Internet'
            sourcePortRange: '*'
            destinationApplicationSecurityGroups: [
              { id: asgWeb.id }
            ]
            destinationPortRange: '8080'
          }
        }
      ]
    )
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: 'nsg-app'
  location: location
  properties: {
    securityRules: enableJumpSsh ? [
      {
        name: 'allow-web-to-app-22'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            { id: asgWeb.id }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgApp.id }
          ]
          destinationPortRange: '22'
        }
      }
    ] : []
  }
}

resource nsgDb 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: 'nsg-db'
  location: location
  properties: {
    securityRules: [
      // Explicitly deny app -> db on tcp/3306
      {
        name: 'deny-app-to-db-3306'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            { id: asgApp.id }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            { id: asgDb.id }
          ]
          destinationPortRange: '3306'
        }
      }
    ]
  }
}

// ---- VMs (NIC-level NSG + ASG membership set inside module) ----
module vmWeb 'vm.bicep' = {
  name: 'vm-web'
  params: {
    vmName: 'web-vm'
    subnetId: vnet.properties.subnets[0].id
    nsgId: nsgWeb.id
    asgIds: [ asgWeb.id ]
    location: location
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    publicIP: true
  }
}

module vmApp 'vm.bicep' = {
  name: 'vm-app'
  params: {
    vmName: 'app-vm'
    subnetId: vnet.properties.subnets[1].id
    nsgId: nsgApp.id
    asgIds: [ asgApp.id ]
    location: location
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    publicIP: false
  }
}

module vmDb 'vm.bicep' = {
  name: 'vm-db'
  params: {
    vmName: 'db-vm'
    subnetId: vnet.properties.subnets[2].id
    nsgId: nsgDb.id
    asgIds: [ asgDb.id ]
    location: location
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    publicIP: false
  }
}

// ---- Helpful outputs ----
output webPublicIp string = vmWeb.outputs.publicIp
output webPrivateIp string = vmWeb.outputs.privateIp
output appPrivateIp string = vmApp.outputs.privateIp
output dbPrivateIp string = vmDb.outputs.privateIp
