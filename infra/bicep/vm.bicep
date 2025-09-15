param vmName string
param subnetId string
param nsgId string
param asgIds array
param location string = resourceGroup().location
param adminUsername string
@secure()
param adminPassword string = ''
param publicIP bool = false

resource pip 'Microsoft.Network/publicIPAddresses@2024-03-01' = if (publicIP) {
  name: '${vmName}-pip'
  location: location
  sku: { name: 'Basic' }
  properties: { publicIPAllocationMethod: 'Dynamic' }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: { id: subnetId }
        publicIPAddress: publicIP ? { id: pip.id } : null
      }
    }]
    networkSecurityGroup: { id: nsgId }
    applicationSecurityGroups: [ for id in asgIds: { id: id } ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: empty(adminPassword) ? null : adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: empty(adminPassword)
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
  }
}
