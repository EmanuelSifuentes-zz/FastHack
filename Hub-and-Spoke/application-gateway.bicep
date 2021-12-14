@description('The location into which the Application Gateway resources should be deployed.')
param location string = resourceGroup().location

@description('The parameters for the application that you want to protect via this Application Gateway')
param appName string 

@description('The minimum number of capacity units for the Application Gateway to use when autoscaling.')
param minimumCapacity int = 2

@description('The maximum number of capacity units for the Application Gateway to use when autoscaling.')
param maximumCapacity int = 10

@description('The hostname (FQDN) of the backend to configure in Application Gateway.')
param backendFqdn string = 'conferenceapi.azurewebsites.net'

@description('Indicates that Application Gateway should override the host header in the request with the host name of the back-end when the request is routed from the Application Gateway to the backend.')
param pickHostNameFromBackendAddress bool = true

@description('The resource ID of the virtual network subnet that the Application Gateway should be deployed into.')
param agwSnetResourceId string

@description('The resource id for the WAF Policy that will be used for the Application Gateway listener')
param wafPolicyId string

@description('The resource id for the public IP address to be used for the Application Gateway')
param agwPipId string

@description('The resource ID of the log analytics workspace that will hold Azure Firewall diagnostics')
param workspaceId string

@description('The name of the SKU to use when creating the Application Gateway.')
@allowed([
  'Standard_Large'
  'Standard_Medium'
  'Standard_Small'
  'Standard_v2'
  'WAF_Large'
  'WAF_Medium'  
  'WAF_v2'
])
param agwSkuName string = 'WAF_v2'

@description('The tier to use when creating the Application Gateway.')
@allowed([
  'Standard'
  'Standard_v2'
  'WAF'
  'WAF_v2'
])
param agwTier string = 'WAF_v2'

var applicationGatewayName = 'agw-hub-prod-eu2-01'
var gatewayIPConfigurationName = 'ipcfg-agw-prod-eu2-01'
var frontendIPConfigurationName = 'feip-agw-prod-eu2-01'
var frontendPort = 80
var frontendPortName = 'feport-agw-prod-eu2-01'
var backendPort = 80
var backendAddressPoolName = 'bepool-${appName}-prod-eu2-01'
var backendHttpSettingName = 'httpsetting-${appName}-prod-eu2-01'
var backendHttpSettingProtocol = 'Http'
var backendHttpSettingCookieBasedAffinity = 'Disabled'
var httpListenerName = 'httplistener-${appName}-prod-eu2-01'
var httpListenerProtocol = 'Http'
var requestRoutingRuleName = 'routingrule-${appName}-prod-eu2-01'

var agwDiagSvcName = 'agw-diag-to-law'


resource applicationGateway 'Microsoft.Network/applicationGateways@2019-09-01' = {
  name: applicationGatewayName
  location: location
  properties: {
    sku: {
      name: agwSkuName
      tier: agwTier
    }
    autoscaleConfiguration: {
      minCapacity: minimumCapacity
      maxCapacity: maximumCapacity
    }
    gatewayIPConfigurations: [
      {
        name: gatewayIPConfigurationName
        properties: {
          subnet: {
            id: agwSnetResourceId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationName
        properties: {
          publicIPAddress: {
            id: agwPipId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: frontendPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendAddressPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: backendFqdn
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingName
        properties: {
          port: backendPort
          protocol: backendHttpSettingProtocol
          cookieBasedAffinity: backendHttpSettingCookieBasedAffinity
          pickHostNameFromBackendAddress: pickHostNameFromBackendAddress
        }
      }
    ]
    httpListeners: [
      {
        name: httpListenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, frontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, frontendPortName)
          }
          firewallPolicy: {
            id: wafPolicyId
          }
          protocol: httpListenerProtocol
        }
      }
    ]
    requestRoutingRules: [
      {
        name: requestRoutingRuleName
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, httpListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, backendAddressPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, backendHttpSettingName)
          }
        }
      }
    ]
  }
}

resource afwDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: applicationGateway
  name: agwDiagSvcName
  properties: {
    storageAccountId: null
    eventHubName: null
    eventHubAuthorizationRuleId: null
    workspaceId: workspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
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

output agwResourceId string = applicationGateway.id
