targetScope = 'subscription'

@description('Azure region where the test lab will be created.')
param location string = 'japaneast'

@description('Admin username for the Windows VM.')
param adminUsername string

@secure()
@description('Admin password for the Windows VM.')
param adminPassword string

@description('PostgreSQL administrator username.')
param postgresAdministratorLogin string

@secure()
@description('PostgreSQL administrator password.')
param postgresAdministratorPassword string

@description('PostgreSQL username used by Guacamole.')
param guacamolePostgresUsername string

@secure()
@description('PostgreSQL password used by Guacamole.')
param guacamolePostgresPassword string

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

module postgres './postgres.bicep' = {
  name: 'postgresDeployment'
  scope: resourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
    postgresSubnetId: network.outputs.postgresSubnetId
    postgresPrivateDnsZoneId: network.outputs.postgresPrivateDnsZoneId
    administratorLogin: postgresAdministratorLogin
    administratorLoginPassword: postgresAdministratorPassword
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
    subnetId: network.outputs.win11SubnetId

    postgresHostname: postgres.outputs.postgresHostname
    postgresAdministratorLogin: postgresAdministratorLogin
    postgresAdministratorPassword: postgresAdministratorPassword
    guacamolePostgresUsername: guacamolePostgresUsername
    guacamolePostgresPassword: guacamolePostgresPassword
  }

  dependsOn: [
    postgres
  ]
}

module guacamole './guacamole.bicep' = {
  name: 'guacamoleDeployment'
  scope: resourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
    acaSubnetId: network.outputs.acaSubnetId
    postgresHostname: postgres.outputs.postgresHostname
    postgresDatabase: postgres.outputs.postgresDatabaseName
    postgresUsername: guacamolePostgresUsername
    postgresPassword: guacamolePostgresPassword
  }

  dependsOn: [
    win11Compute
  ]
}

output resourceGroupName string = resourceGroupName
output subscriptionId string = subscription().id
output vnetName string = network.outputs.vnetName
output vnetId string = network.outputs.vnetId
output win11SubnetId string = network.outputs.win11SubnetId
output acaSubnetId string = network.outputs.acaSubnetId
output postgresSubnetId string = network.outputs.postgresSubnetId
output postgresPrivateDnsZoneId string = network.outputs.postgresPrivateDnsZoneId
output vmPrivateIpAddress string = win11Compute.outputs.vmPrivateIpAddress
output guacamoleUrl string = guacamole.outputs.containerAppUrl