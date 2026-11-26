param location string
param subscriptionSuffix string
param clientIp string

var vnetName = 'vnet-testlab-${subscriptionSuffix}'
var vnetAddressSpace = '10.10.0.0/24'
var subnetPrefix = '10.10.0.0/24'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-nsg'
  location: location

  properties: {
    securityRules: [
      {
        name: 'allow-rdp-client-ip'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '${clientIp}/32'
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
        name: 'snet-test'
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
  name: 'snet-test'
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output subnetId string = subnet.id