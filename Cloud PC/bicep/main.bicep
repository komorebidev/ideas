targetScope = 'subscription'

@description('Azure region where the test lab will be created.')
param location string = 'japaneast'

@description('Admin username for the test VM.')
param adminUsername string

@secure()
@description('Admin password for the test VM.')
param adminPassword string

var subscriptionSuffix = substring(subscription().id, length(subscription().id) - 4, 4)
var resourceGroupName = 'win11CPC-${subscriptionSuffix}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
}

module network './network.bicep' = {
  name: 'networkDeployment'
  scope: resourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
  }
}

module win11Compute './win11VM.bicep' = {
  name: 'win11VMDeployment'
  scope: resourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: network.outputs.subnetId
  }
}

output resourceGroupName string = resourceGroupName
output subscriptionId string = subscription().id
output vnetName string = network.outputs.vnetName
output vnetId string = network.outputs.vnetId
output subnetId string = network.outputs.subnetId
output vmPrivateIpAddress string = win11VM.outputs.vmPrivateIpAddress