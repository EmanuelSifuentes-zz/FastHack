@description('The location into which the virtual network resources should be deployed.')
param location string = resourceGroup().location

@description('The IP address prefix (CIDR range) to use when deploying the virtual network.')
param hubVnetIpPrefix string = '10.0.0.0/16'

@description('The IP address prefix (CIDR range) to use when deploying the Gateway subnet within the virtual network.')
param gwSnetIpPrefix string = '10.0.200.0/24'

@description('The IP address prefix (CIDR range) to use when deploying the Azure Firewall subnet within the virtual network.')
param afwSnetIpPrefix string = '10.0.201.0/24'

@description('The IP address prefix (CIDR range) to use when deploying the Azure Bastion subnet within the virtual network.')
param bastionSnetIpPrefix string = '10.0.202.0/24'

@description('The IP address prefix (CIDR range) to use when deploying the Application Gateway subnet within the virtual network.')
param agwSnetIpPrefix string = '10.0.203.0/24'

@description('The IP address prefix (CIDR range) to use when deploying the API Management subnet within the virtual network.')
param apimSnetIpPrefix string = '10.0.204.0/24'

@description('The domain name label to attach to the Application Gateway\'s public IP address. This must be unique within the specified location.')
param agwPipDnsLabel string = 'agw${uniqueString(resourceGroup().id)}'

var hubVnetName = 'vnet-hub-prod-eu2-01'
var agwSnetName = 'snet-agw-prod-eu2-01'
var agwNsgName = 'nsg-agw-prod-eu2-01'
var apimSnetName = 'snet-apim-prod-eu2-01'
var apimNsgName = 'nsg-apim-prod-eu2-01'
var agwPipName = 'pip-agw-prod-eu2-01'

resource hubVnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: hubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetIpPrefix
      ]
    }
    subnets: [
      {
        name: agwSnetName
        properties: {
          addressPrefix: agwSnetIpPrefix
          networkSecurityGroup: {
            id: agwNsg.id
          }
        }
      }
      {
        name: apimSnetName
        properties: {
          addressPrefix: apimSnetIpPrefix
          networkSecurityGroup: {
            id: apimNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
            }
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.EventHub'
            }
          ]
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gwSnetIpPrefix
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: afwSnetIpPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSnetIpPrefix
        }
      }
    ]
  }
}

resource agwNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: agwNsgName
  location: location
  properties: {
    securityRules: [
      // Rules for Application Gateway as documented here: https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-faq
      {
        name: 'Allow_GWM'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_AzureLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_Front_Door_to_send_HTTP_traffic'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: 'AzureFrontDoor.Backend'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource apimNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: apimNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow_ApiManagement_In'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '3443'
          ]
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_AppGw_In'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: agwSnetIpPrefix
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_RedisCache_ApimReq_In'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '6381'
            '6382'
            '6383'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_SyncCounter_ApimReq_In'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '4290'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_Storage_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_AAD_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '445'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_SQL_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '1433'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'SQL'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_KeyVault_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_EventHub_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '5671'
            '5672'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_AzureCloud_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '12000'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_AzureMonitor_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '1886'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_SMTP_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '25'
            '587'
            '25028'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 180
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_RedisCache_ApimReq'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '6381'
            '6382'
            '6383'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 190
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow_SyncCounter_ApimReq'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '4290'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource agwPublicIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: agwPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: agwPipDnsLabel
    }
  }
}

output hubVnetName string = hubVnet.name
output hubVnetRgName string = resourceGroup().name
output agwSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, agwSnetName)
output agwPipFqdn string = agwPublicIPAddress.properties.dnsSettings.fqdn
output agwPipId string = agwPublicIPAddress.id
output apimSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, apimSnetName)
output bastionSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'AzureBastionSubnet')
output afwSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'AzureFirewallSubnet')
output gwSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'GatewaySubnet')
