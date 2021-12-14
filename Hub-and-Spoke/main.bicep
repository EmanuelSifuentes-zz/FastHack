targetScope = 'subscription'

param location string = 'EastUs2'

resource wthRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'nw-wth-rg'
  location: location
}
