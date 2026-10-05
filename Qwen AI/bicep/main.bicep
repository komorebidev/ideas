targetScope = 'subscription'

@description('Azure region for the Qwen AI lab.')
param location string = 'japaneast'

@description('Linux VM administrator username.')
param adminUsername string

@secure()
@description('Linux VM administrator password.')
param adminPassword string

var subscriptionSuffix = substring(subscription().id, length(subscription().id) - 4, 4)
var resourceGroupName = 'qwen-${subscriptionSuffix}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
}

module network './network.bicep' = {
  name: 'qwenNetworkDeployment'
  scope: resourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
  }
}

module qwen './qwen.bicep' = {
  name: 'qwenVmDeployment'
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
output vmName string = qwen.outputs.vmName
output vmPublicIpAddress string = qwen.outputs.vmPublicIpAddress
output vmPrivateIpAddress string = qwen.outputs.vmPrivateIpAddress