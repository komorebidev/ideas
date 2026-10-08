param location string
param subscriptionSuffix string

// VNet contains separate ACA, Windows, and PostgreSQL subnets.
var vnetName = 'vnet-win11CPC-${subscriptionSuffix}'
var vnetAddressSpace = '10.10.0.0/24'

// ACA requires a dedicated subnet for VNet integration.
var acaSubnetPrefix = '10.10.0.0/27'

// Windows VM uses a separate subnet from ACA.
var win11SubnetPrefix = '10.10.0.32/27'

// PostgreSQL Private Access requires its own delegated subnet.
var postgresSubnetPrefix = '10.10.0.64/28'

// PostgreSQL private DNS zone.
var postgresPrivateDnsZoneName = 'private.postgres.database.azure.com'

// Allow RDP only from the ACA subnet.
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${vnetName}-nsg'
  location: location

  properties: {
    securityRules: [
      {
        name: 'allow-rdp-from-aca'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: acaSubnetPrefix
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
      // Dedicated subnet for Azure Container Apps.
      {
        name: 'aca-snet'
        properties: {
          addressPrefix: acaSubnetPrefix
        }
      }

      // Separate subnet for the Windows VM.
      {
        name: 'win11CPC-snet'
        properties: {
          addressPrefix: win11SubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }

      // PostgreSQL Flexible Server requires a delegated subnet.
      {
        name: 'postgres-snet'
        properties: {
          addressPrefix: postgresSubnetPrefix

          delegations: [
            {
              name: 'postgresql-flexible-server'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource acaSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'aca-snet'
}

resource win11Subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'win11CPC-snet'
}

resource postgresSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'postgres-snet'
}

// Private DNS zone for PostgreSQL Flexible Server.
resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: postgresPrivateDnsZoneName
  location: 'global'
}

// Link PostgreSQL DNS zone to the VNet.
resource postgresPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: postgresPrivateDnsZone
  name: 'postgres-vnet-link'
  location: 'global'

  properties: {
    virtualNetwork: {
      id: vnet.id
    }

    registrationEnabled: false
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id

// Used by the Container Apps Environment.
output acaSubnetId string = acaSubnet.id

// Used by the Windows VM NIC.
output win11SubnetId string = win11Subnet.id

// Used by the PostgreSQL Flexible Server.
output postgresSubnetId string = postgresSubnet.id

// Used by the PostgreSQL Flexible Server private network configuration.
output postgresPrivateDnsZoneId string = postgresPrivateDnsZone.id