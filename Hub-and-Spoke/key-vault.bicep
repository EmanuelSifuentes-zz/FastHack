@description('Deployment location')
param location string = resourceGroup().location

@description('Name of the managed identity that Azure Firewall uses to retrieve secrets from key vault')
param afwManagedIdentityName string

@description('Name of the resource group where the managed identity of the Azure Firewall was deployed')
param afwManagedIdentityRgName string

@description('Unique identifier to be prepended to the key vault name')
@minLength(3)
@maxLength(5)
param kvUniqueId string

var keyVaultName = '${kvUniqueId}-kv-hub-prod-eu2-01'

resource afwManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  scope: resourceGroup(afwManagedIdentityRgName)
  name: afwManagedIdentityName
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: afwManagedIdentity.properties.principalId
        tenantId: afwManagedIdentity.properties.tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}
