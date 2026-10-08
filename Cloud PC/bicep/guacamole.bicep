param location string
param subscriptionSuffix string
param acaSubnetId string

param postgresHostname string
param postgresDatabase string
param postgresUsername string

@secure()
param postgresPassword string

var environmentName = 'aca-guacamole-${subscriptionSuffix}'
var containerAppName = 'guacamole-${subscriptionSuffix}'

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location

  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: acaSubnetId
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location

  properties: {
    managedEnvironmentId: environment.id

    configuration: {
      activeRevisionsMode: 'Single'

      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }

      secrets: [
        {
          name: 'postgres-password'
          value: postgresPassword
        }
      ]
    }

    template: {
      containers: [
        {
          name: 'guacamole'
          image: 'guacamole/guacamole:1.6.0'

          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }

          env: [
            {
              name: 'GUACD_HOSTNAME'
              value: '127.0.0.1'
            }
            {
              name: 'GUACD_PORT'
              value: '4822'
            }
            {
              name: 'POSTGRESQL_ENABLED'
              value: 'true'
            }
            {
              name: 'POSTGRESQL_HOSTNAME'
              value: postgresHostname
            }
            {
              name: 'POSTGRESQL_PORT'
              value: '5432'
            }
            {
              name: 'POSTGRESQL_DATABASE'
              value: postgresDatabase
            }
            {
              name: 'POSTGRESQL_USERNAME'
              value: postgresUsername
            }
            {
              name: 'POSTGRESQL_PASSWORD'
              secretRef: 'postgres-password'
            }
          ]
        }

        {
          name: 'guacd'
          image: 'guacamole/guacd:1.6.0'

          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]

      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'