param location string
param subscriptionSuffix string
param postgresSubnetId string
param postgresPrivateDnsZoneId string

param administratorLogin string

@secure()
param administratorLoginPassword string

var serverName = 'postgres-guacamole-${subscriptionSuffix}'
var databaseName = 'guacamole_db'

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location

  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }

  properties: {
    version: '16'

    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword

    storage: {
      storageSizeGB: 32
      autoGrow: 'Disabled'
    }

    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }

    highAvailability: {
      mode: 'Disabled'
    }

    network: {
      delegatedSubnetResourceId: postgresSubnetId
      privateDnsZoneArmResourceId: postgresPrivateDnsZoneId
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgres
  name: databaseName

  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

output postgresServerName string = postgres.name
output postgresHostname string = postgres.properties.fullyQualifiedDomainName
output postgresDatabaseName string = database.name