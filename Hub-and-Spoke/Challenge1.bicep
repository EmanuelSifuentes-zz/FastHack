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

@description('The IP address prefix (CIDR range) to use when deploying the workload subnet within the virtual network.')
param workloadSnetIpPrefix string = '10.0.204.0/24'

@description('The domain name label to attach to the Application Gateway\'s public IP address. This must be unique within the specified location.')
param agwPipDnsLabel string = 'agw${uniqueString(resourceGroup().id)}'

var hubVnetName = 'vnet-hub-prod-01'
var agwSnetName = 'snet-agw-prod-01'
var agwNsgName = 'nsg-agw-prod-01'
var workloadSnetName = 'snet-workload-prod-01'
var workloadNsgName = 'nsg-workload-prod-01'
var agwPipName = 'pip-agw-prod-01'

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
output bastionSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'AzureBastionSubnet')
output afwSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'AzureFirewallSubnet')
output gwSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'GatewaySubnet')
