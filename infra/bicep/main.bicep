param location string = 'canadacentral'
param adminUsername string = 'azureuser'

@secure()
param adminPassword string = ''

var vnetName = 'NetShieldVnet'
var webSubnetName = 'web-subnet'
var appSubnetName = 'app-subnet'
var dbSubnetName  = 'db-subnet'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroup().name
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      { name: webSubnetName, properties: { addressPrefix: '10.0.1.0/24' } }
      { name: appSubnetName, properties: { addressPrefix: '10.0.2.0/24' } }
      { name: dbSubnetName,  properties: { addressPrefix: '10.0.3.0/24' } }
    ]
  }
}

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

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: 'nsg-web'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-app-to-web-8080'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [ { id: asgApp.id } ]
          destinationApplicationSecurityGroups: [ { id: asgWeb.id } ]
          sourcePortRange: '*'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'deny-any-to-db'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationApplicationSecurityGroups: [ { id: asgDb.id } ]
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'allow-internet-to-web-8080'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          destinationApplicationSecurityGroups: [ { id: asgWeb.id } ]
          sourcePortRange: '*'
          destinationPortRange: '8080'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: 'nsg-app'
  location: location
}
resource nsgDb 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: 'nsg-db'
  location: location
}

@description('Creates a VM with NIC associated to a subnet, NSG, and ASG')
module vmWeb 'vm.bicep' = {
  name: 'vm-web'
  params: {
    vmName: 'web-vm'
    subnetId: vnet.properties.subnets[0].id
    nsgId: nsgWeb.id
    asgIds: [ asgWeb.id ]
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
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
    adminPassword: adminPassword
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
    adminPassword: adminPassword
    publicIP: false
  }
}
