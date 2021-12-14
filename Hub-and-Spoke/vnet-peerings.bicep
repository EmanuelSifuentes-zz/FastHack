@description('The name of the local virtual network')
param virtualNetworkName string

@description('Set to true to allow traffic forwarded by an NVA whose origin is not part of the hub VNET')
param allowForwardedTraffic bool = true

@description('Set to true if you have a VNET gateway attached to this VNET and want to allow traffic from the peered VNET to flow through the gateway')
param allowGatewayTransit bool = false

@description('Set to true if you want to enable communication between the two VNETs through the default VirtualNetwork flow')
param allowVirtualNetworkAccess bool = true

@description('Set to true to allow traffic from this VNET to flow through a VNET gateway attached to the VNET you are peering with')
param useRemoteGateways bool = true

param remoteResourceGroup string
param remoteVirtualNetworkName string
 
resource remotevnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(remoteResourceGroup)  
  name: remoteVirtualNetworkName
}
 
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: '${virtualNetworkName}/Peering-To-${remoteVirtualNetworkName}'
  properties: {
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remotevnet.id
    }
  }
}
