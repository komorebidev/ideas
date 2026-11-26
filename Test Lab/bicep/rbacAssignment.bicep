targetScope = 'resourceGroup'

@description('Resource ID of the role definition.')
param roleDefinitionId string

@description('Principal ID of the Flask web app managed identity.')
param principalId string

resource labRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = labRoleAssignment.id