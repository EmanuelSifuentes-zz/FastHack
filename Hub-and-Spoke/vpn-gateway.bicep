@description('Deployment location')
param location string = resourceGroup().location

@description('The resource ID for the Azure Firewall subnet')
param gwSnetId string

@description('Set to true to enable active-active mode on the VPN gateway')
param activeActiveMode bool = true

@description('Set to true to enable BGP on the VPN gateway')
param enableBgp bool  = true

@description('Select the SKU of your VPN gateway')
@allowed([
  'VpnGw2'
  'VpnGw3'
  'VpnGw4'
  'VpnGw5'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
])
param vpnGwSku string = 'VpnGw2'

@description('Select the generation of gateway to deploy')
@allowed([
  'Generation1'
  'Generation2'
])
param vpnGwGen string = 'Generation2'

@description('Select the type of gateway to deploy')
@allowed([
  'Vpn'
  'ExpressRoute'
])
param gatewayType string = 'Vpn'

@description('Select how IPsec traffic selectors will be set on connection.\n Route-based: Any-to-any traffic selectors, typically a router where each IPsec tunnel is a VTI \n Policy-based: Prefixe based traffic selectors, typically a firewall to perform packet filtering and rules processing')
@allowed([
  'PolicyBased'
  'RouteBased'
])
param vpnType string = 'RouteBased'

@description('The private ASN to be used for the VPN Gateway; must differ from your on-prem VPN ASN')
param asn int = 65515

var vpnGwName = 'vpn-gw-prod-eu2-01'
var pipVpnGwName1 = 'pip-vpn-gw-prod-eu2-01'
var pipVpnGwName2 = 'pip-vpn-gw-prod-eu2-02'
var ipcfgVpnGwName1 = 'ipcfg-vpn-gw-prod-eu2-01'
var ipcfgVpnGwName2 = 'ipcfg-vpn-gw-prod-eu2-02'

resource vpnGwPublicIPAddress1 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: pipVpnGwName1
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vpnGwPublicIPAddress2 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (activeActiveMode) {
  name: pipVpnGwName2
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vpnGw 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: vpnGwName
  location: location
  properties: {
    ipConfigurations: activeActiveMode ? [
      {
        name: ipcfgVpnGwName1
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gwSnetId
          }
          publicIPAddress: {
            id: vpnGwPublicIPAddress1.id
          }
        }
      }
      {
        name: ipcfgVpnGwName2
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gwSnetId
          }
          publicIPAddress: {
            id: vpnGwPublicIPAddress2.id
          }
        }
      }
    ] : [
      {
        properties: {
          name: ipcfgVpnGwName1
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gwSnetId
          }
          publicIPAddress: {
            id: vpnGwPublicIPAddress1.id
          }
        }
      }
    ]
    activeActive: activeActiveMode
    gatewayType: gatewayType
    vpnType: vpnType
    enableBgp: enableBgp ? enableBgp : !(enableBgp)
    bgpSettings: {
      asn: asn
    }
    vpnGatewayGeneration: vpnGwGen
    sku: {
      name: vpnGwSku
      tier: vpnGwSku
    }
  }
}
