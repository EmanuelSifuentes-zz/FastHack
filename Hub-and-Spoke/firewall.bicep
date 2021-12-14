@description('Deployment location')
param location string = resourceGroup().location

@description('The resource ID for the Azure Firewall subnet')
param afwSnetId string

@description('The DNS servers to be used by Azure Firewall to proxy DNS requests to')
param dnsServers array = [
  '168.63.129.16'
]

@description('Choose if Azure Firewall acts as a DNS proxy. \nAzure Firewall must act as a DNS proxy in order to have FQDN filtering in Network rules')
param afwDnsProxy bool = true

@description('Threat intelligence based filtering can be enabled for your firewall to alert and block traffic to/from known malicious IP addresses and domains.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string = 'Alert'

@description('IDPS can be enabled for Azure Firewall Premium to detect and prevent attacks.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param intrusionDetectionMode string = 'Alert'

@description('The resource ID of the log analytics workspace that will hold Azure Firewall diagnostics')
param workspaceId string

var afwName = 'afw-hub-prod-eu2-01'
var afwPublicIpName = 'pip-afw-prod-eu2-01'
var afwPolicyName = 'pol-afw-prod-eu2-01'
var afwManagedIdentityName = 'id-afw-prod-eu2-01'
var afwDefaultRuleCollectionGroupName = 'internal-traffic-rcg'
var afwAvdRuleCollectionGroupName = 'avd-traffic-rcg'
var afwDiagSvcName = 'afw-diag-to-law'


resource afwManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: afwManagedIdentityName
  location: location
}

resource afwPublicIp 'Microsoft.Network/publicIpAddresses@2020-07-01' = {
  name: afwPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource afwPolicy 'Microsoft.Network/firewallPolicies@2021-02-01' = {
  name: afwPolicyName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${afwManagedIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      tier: 'Premium'
    }
    dnsSettings: {
      servers: dnsServers
      enableProxy: afwDnsProxy
    }
    threatIntelMode: threatIntelMode
    intrusionDetection: {
      mode: intrusionDetectionMode
      configuration: {
        signatureOverrides: []
        bypassTrafficSettings: []
      }
    }
  }
}


resource afwPolicy_Internal_PolicyRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-07-01' = {
  parent: afwPolicy
  name: afwDefaultRuleCollectionGroupName
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'Internal-traffic-allow-nrc'
        priority: 210
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-all-internal-traffic'
            description: 'This rule allows all traffic to and from 10.0.0.0/8 address space'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              '10.0.0.0/8'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource afwPolicy_Avd_PolicyRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-07-01' = {
  parent: afwPolicy
  name: afwAvdRuleCollectionGroupName
  properties: {
    priority: 300
    ruleCollections: [
      {
        name: 'allow-AVD-traffic-netRc'
        priority: 310
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allow-time-sync'
            description: 'This rule allows time synchronization by enabling UDP port 123 for time.windows.com'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationFqdns: [
              'time.windows.com'
            ]
            destinationPorts: [
              '123'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-KMS-activation'
            description: 'This rule allows KMS activation by enabling TCP port 1688 for kms.core.windows.net'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              '23.102.135.246'
            ]
            destinationPorts: [
              '1688'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-DNS'
            description: 'This rule allows DNS by enabling TCP and UDP port 53'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '53'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-AAD'
            description: 'This rule allows AAD traffic by allowing TCP 80 and 443'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              'AzureActiveDirectory'
            ]
            destinationPorts: [
              '80'
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-AzReqs'
            description: 'This rule allows traffic to the Azure DNS Recurisve resolver and IDMS endpoint'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              '169.254.169.254'
              '168.63.129.16'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        name: 'allow-AVD-traffic-appRc'
        priority: 320
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'allow-AVD-fqdnTag-traffic'
            description: 'This rule allows AVD hosts to reach all required endpoints for functionality'
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            fqdnTags: [
              'WindowsVirtualDesktop'
              'WindowsUpdate'
              'WindowsDiagnostics'
              'MicrosoftActiveProtectionService'
            ]
            protocols: [
              {
                port: 443
                protocolType: 'Https'
              }
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'allow-AVD-stg-sb-traffic'
            description: 'This rule allows AVD hosts to reach all required service bus accounts and storage accounts for functionality'
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            targetFqdns: [
              '*xt.blob.core.windows.net'
              '*eh.servicebus.windows.net'
            ]
            protocols: [
              {
                port: 443
                protocolType: 'Https'
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn:[
    afwPolicy_Internal_PolicyRules
  ]
}

resource afw 'Microsoft.Network/azureFirewalls@2020-07-01' = {
  name: afwName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'FirewallIPConfiguration'
        properties: {
          subnet: {
            id: afwSnetId
          }
          publicIPAddress: {
            id: afwPublicIp.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: afwPolicy.id
    }
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
  }
  dependsOn: [
    afwPolicy_Internal_PolicyRules
    afwPolicy_Avd_PolicyRules
  ]
}

resource afwDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: afw
  name: afwDiagSvcName
  properties: {
    storageAccountId: null
    eventHubName: null
    eventHubAuthorizationRuleId: null
    workspaceId: workspaceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ] 
  }
}

output afwPrivateIp string = afw.properties.ipConfigurations[0].properties.privateIPAddress
output afwManagedIdentityName string = afwManagedIdentity.name
output afwManagedIdentityRgName string = resourceGroup().name
