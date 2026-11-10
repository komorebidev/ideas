targetScope = 'subscription'

@description('Azure region for the Automation Account.')
param location string = 'japaneast'

@description('Resource group to contain the cleanup Automation Account. Keep this group outside all cleanup patterns.')
param cleanupResourceGroupName string = 'rg-nightly-cleanup'

@description('Automation Account name.')
param automationAccountName string = 'aa-nightly-rg-cleanup'

@description('Wildcard patterns for resource group names to delete. Example: testlab-*')
param resourceGroupNamePatterns array = [
  'lab*'
]

@description('Schedule start time, local Japan time, with UTC offset.')
param scheduleTime string = '2026-11-10T19:00:00+09:00'

@description('Set true to list matches without deleting. Keep true for initial validation.')
param dryRun bool = false

resource cleanupRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: cleanupResourceGroupName
  location: location
}

module automation 'automation.bicep' = {
  name: 'nightlyRgCleanupAutomation'
  scope: cleanupRg
  params: {
    location: location
    automationAccountName: automationAccountName
    resourceGroupNamePatterns: resourceGroupNamePatterns
    scheduleTime: scheduleTime
    dryRun: dryRun
    excludedResourceGroupName: cleanupResourceGroupName
  }
}

var contributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
)

resource cleanupRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, automationAccountName, contributorRoleDefinitionId)
  scope: subscription()
  properties: {
    principalId: automation.outputs.automationPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinitionId
  }
}