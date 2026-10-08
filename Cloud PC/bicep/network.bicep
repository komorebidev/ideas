param location string
param subscriptionSuffix string

var vnetName = 'vnet-win11CPC-${subscriptionSuffix}'
var vnetAddressSpace = '10.10.0.0/24'
var subnetPrefix = '10.10.0.0/24'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-nsg'
  location: location

  properties: {
    securityRules: [
      {
        name: 'allow-rdp-from-vnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
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
        name: 'win11CPC-snet'
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
  name: 'win11CPC-snet'
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output subnetId string = subnet.id