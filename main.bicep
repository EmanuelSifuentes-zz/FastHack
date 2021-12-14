targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'AdvNw-WTH-RG'
  location: deployment().location
}
/*
module stgDeploy 'AdvNw-WTH.bicep' = {
  name: 'stgDeploy'
  scope: rg
  params: {
    name: 'sifteststg'
    location: 'EastUS'
  }
}
*/
