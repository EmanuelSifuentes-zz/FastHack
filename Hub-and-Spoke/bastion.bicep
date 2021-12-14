@description('Deployment location')
param location string = resourceGroup().location

@description('The resource ID of the Azure Bastion subnet')
param bastionSnetId string

var bastionPipName = 'pip-bastion-prod-eu2-01'
var bastionName = 'bas-hub-prod-eu2-01'

resource bastionPublicIP 'Microsoft.Network/publicIpAddresses@2020-07-01' = {
  name: bastionPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-07-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'BastionIpConfiguration'
        properties: {
          subnet: {
            id: bastionSnetId
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
}
