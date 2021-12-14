@description('The location into which the virtual network resources should be deployed.')
param location string = resourceGroup().location

@description('The operating environment of the spoke resources.')
param spokeEnvironment string

@description('The IP address prefix (CIDR range) to used when deploying the virtual network.')
param spokeIpPrefix string

@description('The name of the Spoke to be used when deploying the virtual network.')
param spokeName string

@description('The private IP address of the Azure Firewall internal load balancer')
param afwPrivateIp string

@description('The properties for the spoke subnets to be deployed within the VNET. They include NSGs and Route Tables as part of deployment')
param spokeSubnetProperties array = [
  {
    name: 'snet-front-${spokeEnvironment}-${location}-01'
    addressSpace: '${octet1}.${octet2}.1.0/24'
    nsgName: 'nsg-front-${spokeEnvironment}-${location}-01'
    rtName: 'rt-front-${spokeEnvironment}-${location}-01'
  }
  {
    name: 'snet-mid-${spokeEnvironment}-${location}-01'
    addressSpace: '${octet1}.${octet2}.2.0/24'
    nsgName: 'nsg-mid-${spokeEnvironment}-${location}-01'
    rtName: 'rt-mid-${spokeEnvironment}-${location}-01'
  }
  {
    name: 'snet-back-${spokeEnvironment}-${location}-01'
    addressSpace: '${octet1}.${octet2}.3.0/24'
    nsgName: 'nsg-back-${spokeEnvironment}-${location}-01'
    rtName: 'rt-back-${spokeEnvironment}-${location}-01'
  }
]

param octet1 int = int(split(spokeIpPrefix, '.')[0])
param octet2 int = int(split(spokeIpPrefix, '.')[1])

var spokeVnetName = 'vnet-${spokeName}-${spokeEnvironment}-${location}-01'

resource spokeVnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: spokeVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeIpPrefix
      ]
    }
    subnets: [for (spokeSubnet, i) in spokeSubnetProperties : {
      name: spokeSubnet.name
      properties: {
        addressPrefix: spokeSubnet.addressSpace
        routeTable: {
          id: routeTable[i].id
        }
        networkSecurityGroup: {
          id: nsg[i].id
        }
      }
    }]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = [for spokeSubnet in spokeSubnetProperties: {
  name: spokeSubnet.nsgName
  location: location
}]

resource routeTable 'Microsoft.Network/routeTables@2020-05-01' = [for spokeSubnet in spokeSubnetProperties: {
  name: spokeSubnet.rtName
  location: location
  properties: {
    routes: [
      {
        name: 'defaultRoute_via_Azfw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: afwPrivateIp
        }
      }
    ]
    disableBgpRoutePropagation: true
  }
}]

output spokeVnetName string = spokeVnet.name
output spokeVnetRgName string = resourceGroup().name
