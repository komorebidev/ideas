targetScope = 'subscription'

@description('Azure region where the test lab will be created.')
param location string = 'japaneast'

@description('Admin username for the test VM.')
param adminUsername string

@secure()
@description('Admin password for the test VM.')
param adminPassword string

@description('Your local public IP address for RDP access.')
param clientIp string

var subscriptionSuffix = substring(subscription().id, length(subscription().id) - 4, 4)
var labresourceGroupName = 'testlab-${subscriptionSuffix}'
var appresourceGroupName = 'testlabapp-${subscriptionSuffix}'

resource labresourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: labresourceGroupName
  location: location
}
resource appresourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: appresourceGroupName
  location: location
}

module network './network.bicep' = {
  name: 'networkDeployment'
  scope: labresourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
    clientIp: clientIp
  }
}

module testlab './testlab.bicep' = {
  name: 'testlabDeployment'
  scope: labresourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: network.outputs.subnetId
  }
}

module flask './flask.bicep' = {
  name: 'flask-deployment'
  scope: appresourceGroup
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
    appServicePlanId: servicePlan.outputs.appServicePlanId
    labResourceGroupName: labresourceGroupName
    subscriptionId: subscription().id
    vmName: testlab.outputs.vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

module servicePlan './serviceplan.bicep' = {
  scope: appresourceGroup
  name: 'serviceplan-deployment'
  params: {
    location: location
    subscriptionSuffix: subscriptionSuffix
  }
}

module rbac './rbac.bicep' = {
  name: 'rbacDefinitionDeployment'
  params: {
    labResourceGroupName: labresourceGroupName
  }
}

/*module rbacAssignment './rbacAssignment.bicep' = {
  name: 'rbacAssignmentDeployment'
  scope: labresourceGroup
  params: {
    roleDefinitionId: rbac.outputs.roleDefinitionId
    principalId: flask.outputs.principalId
  }
}
*/

module rbacAssignment './rbacAssignment.bicep' = {
  name: 'rbacAssignmentDeployment'
  scope: labresourceGroup
  params: {
    principalId: flask.outputs.principalId // <-- Uses the output from your flask module!
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Virtual Machine Contributor
  }
}

output labResourceGroupName string = labresourceGroupName
output appResourceGroupName string = appresourceGroupName
output webAppName string = flask.outputs.webAppName
output webAppUrl string = flask.outputs.webAppUrl
output subscriptionId string = subscription().id
output vnetName string = network.outputs.vnetName
output vnetId string = network.outputs.vnetId
output subnetId string = network.outputs.subnetId
output vmName string = network.outputs.vnetName
output vmPublicIpAddress string = testlab.outputs.vmPublicIpAddress
output vmPrivateIpAddress string = testlab.outputs.vmPrivateIpAddress
output vmAdminUsername string = testlab.outputs.adminUsername
@secure()
output vmAdminPassword string = testlab.outputs.adminPassword