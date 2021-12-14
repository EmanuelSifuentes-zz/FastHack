@description('The location into which the Application Gateway resources should be deployed.')
param location string = resourceGroup().location

@description('The SKU for your log analytics workspace')
@allowed([
  'CapacityReservation'
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param lawSku string = 'PerGB2018'

@description('The retention period for your log analytics workspace data')
@minValue(30)
@maxValue(730)
param lawRetentionInDays int = 365

var lawName = 'log-hub-prod-eu2-01'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: lawSku
    }
    retentionInDays: lawRetentionInDays
  }
}

output lawId string = logAnalyticsWorkspace.id
output DiagnosticsWorkspaceRgId string = resourceGroup().name
output DiagnosticsWorkspaceName string = logAnalyticsWorkspace.name
