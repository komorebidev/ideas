targetScope = 'resourceGroup'

@description('Azure region for the Flask web app.')
param location string

@description('Suffix derived from the subscription ID.')
param subscriptionSuffix string

@description('Resource ID of the App Service Plan.')
param appServicePlanId string

@description('Name of the disposable lab resource group.')
param labResourceGroupName string

@description('Azure subscription ID.')
param subscriptionId string

@description('Name of the virtual machine to control.')
param vmName string

@description('Admin username for the test VM.')
param adminUsername string

@secure()
@description('Admin password for the test VM.')
param adminPassword string

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'labapp-${subscriptionSuffix}'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      alwaysOn: false
      appCommandLine: 'gunicorn --bind=0.0.0.0:8000 --timeout 120 app:app'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'LAB_RESOURCE_GROUP'
          value: labResourceGroupName
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscription().subscriptionId // <-- Use subscriptionId instead of id!
        }
        {
          name: 'VM_ADMIN_USERNAME'
          value: adminUsername
        }
        {
          name: 'VM_ADMIN_PASSWORD'
          value: adminPassword
        }
        {
          name: 'VM_NAME'
          value: vmName
        }
      ]
    }
  }
}

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output principalId string = webApp.identity.principalId
