param location string
param subscriptionSuffix string

var vnetName = 'vnet-qwen-${subscriptionSuffix}'
var vnetAddressSpace = '10.10.1.0/24'
var subnetPrefix = '10.10.1.0/24'
var subnetName = 'snet-qwen'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-nsg'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: subnetName
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output subnetId string = subnet.id