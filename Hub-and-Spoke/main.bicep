targetScope = 'subscription'

@description('The name of the resource group to host the hub resources')
param hubRgName string = 'rg-hub-prod-01'

@description('The location of the resource group to host the hub resources')
param hubRgLocation string = 'eastus'

@description('The name of the application that you will be exposing')
param appName string 

@description('The parameters of the spokes you wish to deploy in Azure')
param spokeParams array

@description('Unique identifier to be prepended to the key vault name')
@minLength(3)
@maxLength(5)
param kvUniqueId string

@description('Unique string appended to each deployment name')
param deploymentId string = toLower(uniqueString(utcNow()))

resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: hubRgName
  location: hubRgLocation
}

resource spokeRgs 'Microsoft.Resources/resourceGroups@2021-04-01' = [for spoke in spokeParams: {
  name: spoke.rgName
  location: spoke.rgLocation
}]

module hubNetwork 'hub-network.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'hubNetwork-${deploymentId}'
}

module firewall 'firewall.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'firewall-${deploymentId}'
  params: {
    afwSnetId: hubNetwork.outputs.afwSnetId
    workspaceId: logAnalyticsWorkspace.outputs.lawId
  }
}

module bastion 'bastion.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'bastion-${deploymentId}'
  params: {
    bastionSnetId: hubNetwork.outputs.bastionSnetId
  }
}

module keyVault 'key-vault.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'keyVault-${deploymentId}'
  params : {
    kvUniqueId: kvUniqueId
    afwManagedIdentityName: firewall.outputs.afwManagedIdentityName
    afwManagedIdentityRgName: firewall.outputs.afwManagedIdentityRgName
  }
}

module spokeNetworks 'spoke-network.bicep' = [for (spoke, i) in spokeParams: {
  scope: resourceGroup(spokeRgs[i].name)
  name: '${spoke.name}Network-${deploymentId}'
  params: {
    spokeName: spoke.name
    spokeIpPrefix: spoke.ipPrefix
    spokeEnvironment: spoke.environment
    afwPrivateIp: firewall.outputs.afwPrivateIp
  }
}]

module hubToSpokePeering 'vnet-peerings.bicep' = [for (spoke, i) in spokeParams: {
  scope: resourceGroup(hubRg.name)
  name: 'hubTo${spoke.name}Peering-${deploymentId}'
  params: {
    remoteResourceGroup: spokeNetworks[i].outputs.spokeVnetRgName
    remoteVirtualNetworkName: spokeNetworks[i].outputs.spokeVnetName
    virtualNetworkName: hubNetwork.outputs.hubVnetName
    useRemoteGateways: false
  }
  dependsOn: [
    hubNetwork
    spokeNetworks
  ]
}]

module spokeToHubPeering 'vnet-peerings.bicep' = [for (spoke, i) in spokeParams: {
  scope: resourceGroup(spokeRgs[i].name)
  name: '${spoke.name}ToHubPeering-${deploymentId}'
  params: {
    remoteResourceGroup: hubNetwork.outputs.hubVnetRgName
    remoteVirtualNetworkName: hubNetwork.outputs.hubVnetName
    virtualNetworkName: spokeNetworks[i].outputs.spokeVnetName
    useRemoteGateways: false
  }
  dependsOn: [
    hubNetwork
    spokeNetworks
  ]
}]


module frontDoor 'front-door.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'front-door-${deploymentId}'
  params: {
    agwPipFqdn: hubNetwork.outputs.agwPipFqdn
  }
}

module waf 'waf.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'waf-${deploymentId}'
  params: {
    frontDoorUniqueId: frontDoor.outputs.frontDoorId
  }
}

module applicationGateway 'application-gateway.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'applicationGateway-${deploymentId}'
  params: {
    agwSnetResourceId: hubNetwork.outputs.agwSnetId
    agwPipId: hubNetwork.outputs.agwPipId
    appName: appName
    wafPolicyId: waf.outputs.wafPolicyId
    workspaceId: logAnalyticsWorkspace.outputs.lawId
  }
}

module vpnGateway 'vpn-gateway.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'vpnGateway-${deploymentId}'
  params: {
    gwSnetId: hubNetwork.outputs.gwSnetId
  }
}

module logAnalyticsWorkspace 'log-analytics.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'logAnalytics-${deploymentId}'
}
